import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/prompt_builder.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../screens/chat_helpers.dart';
import '../services/ai_service.dart';
import '../services/chat_storage.dart';
import '../services/chat_stream_event.dart';
import '../services/connectivity_service.dart';
import '../services/memory_storage.dart';
import '../services/notification_service.dart';
import '../services/personalization_storage.dart';
import '../tools/tools.dart';
import '../widgets/ai_settings_sheet.dart';

/// 单聊页面的业务控制器。
///
/// 负责会话管理、消息发送、AI 流式响应、工具状态维护等；
/// UI 层只负责渲染与输入控件，通过 [ChangeNotifier] 监听状态变化。
class ChatController extends ChangeNotifier {
  ChatController({
    this.initialSessionId,
    AISettings? aiSettings,
    ToolRegistry? toolRegistry,
    ChatStorage? chatStorage,
    this.onNeedScroll,
  })  : _aiSettings = aiSettings ?? AISettings(),
        _toolRegistry = toolRegistry ?? ToolRegistry(),
        _chatStorage = chatStorage ?? ChatStorage() {
    registerAllTools(_toolRegistry);
  }

  final String? initialSessionId;
  final AISettings _aiSettings;
  final ToolRegistry _toolRegistry;
  final ChatStorage _chatStorage;

  /// UI 层传入的滚屏回调，控制器不关心 ScrollController。
  final VoidCallback? onNeedScroll;

  String? _sessionId;
  List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];
  bool _isLoading = false;

  File? _pendingAttachment;
  String _pendingAttachmentType = '';

  StreamSubscription<ChatStreamEvent>? _aiStream;
  List<TimelineStep>? _currentSteps;

  bool _disposed = false;

  // ═══ Public getters ═══

  String? get currentSessionId => _sessionId;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  bool get isLoading => _isLoading;
  File? get pendingAttachment => _pendingAttachment;
  String get pendingAttachmentType => _pendingAttachmentType;
  AISettings get aiSettings => _aiSettings;

  // ═══ Lifecycle ═══

  Future<void> initialize() async {
    await _aiSettings.load();
    await _warmUpCaches();
    _sessions = await _chatStorage.loadAll();
    final sid = initialSessionId ?? (_sessions.isNotEmpty ? _sessions.first.id : null);
    if (sid != null) {
      await loadSession(sid);
    } else {
      newSession();
    }
    if (!_disposed) _notify();
  }

  /// 预热记忆与个人化缓存，避免首次发消息时再加载。
  Future<void> _warmUpCaches() async {
    await MemoryStorage().loadAll();
    await PersonalizationStorage().load();
  }

  @override
  void dispose() {
    _disposed = true;
    _aiStream?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ═══ Session management ═══

  void newSession() {
    _sessionId = const Uuid().v4();
    _messages = [];
    _notify();
  }

  Future<void> loadSession(String id) async {
    _sessionId = id;
    final sessions = await _chatStorage.loadAll();
    final session = sessions.where((s) => s.id == id).firstOrNull;
    _messages = session?.messages.map((m) => ChatMessage(
          text: m.text,
          isUser: m.isUser,
        )).toList() ??
        [];
    _notify();
  }

  Future<void> saveSession() async {
    if (_sessionId == null || _messages.isEmpty) return;
    final userMsg = _messages.where((m) => m.isUser).firstOrNull;
    final title = userMsg != null
        ? userMsg.text.replaceAll('\n', ' ').substring(0, userMsg.text.length.clamp(0, 30)).trim()
        : '新对话';
    await _chatStorage.save(ChatSession(
      id: _sessionId!,
      title: title,
      messages: _messages.map((m) => ChatMessage(text: m.text, isUser: m.isUser)).toList(),
      updatedAt: DateTime.now(),
    ));
    _chatStorage.clearCache();
    _sessions = await _chatStorage.loadAll();
    _notify();
  }

  Future<void> switchSession(String id) async {
    await saveSession();
    await loadSession(id);
  }

  Future<void> deleteSession(String id) async {
    await _chatStorage.delete(id);
    _sessions = await _chatStorage.loadAll();
    if (id == _sessionId) {
      newSession();
    } else {
      _notify();
    }
  }

  Future<void> refreshSessions() async {
    _sessions = await _chatStorage.loadAll();
    _notify();
  }

  void clearSessions() {
    _sessions = [];
    _notify();
  }

  // ═══ Attachment ═══

  void setAttachment(File file, String type) {
    _pendingAttachment = file;
    _pendingAttachmentType = type;
    _notify();
  }

  void clearAttachment() {
    _pendingAttachment = null;
    _pendingAttachmentType = '';
    _notify();
  }

  // ═══ Message sending ═══

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && _pendingAttachment == null) || _isLoading) return;
    if (_sessionId == null) newSession();

    _toolRegistry.resetCallCounts();

    if (!_aiSettings.hasVendor) {
      _messages.add(ChatMessage(
          text: '请先配置 AI 后端（点击输入框内存图标）', isUser: false));
      _notify();
      onNeedScroll?.call();
      return;
    }

    if (!await ConnectivityService().check()) {
      _messages.add(ChatMessage(
          text: '当前无网络连接，请检查网络后重试', isUser: false));
      _notify();
      onNeedScroll?.call();
      return;
    }

    String displayText = trimmed;
    String? attachmentBase64;
    String? attachmentName;
    if (_pendingAttachment != null) {
      final bytes = await _pendingAttachment!.readAsBytes();
      attachmentBase64 = base64Encode(bytes);
      attachmentName = _pendingAttachment!.path.split(Platform.pathSeparator).last;
      final typeLabel = _pendingAttachmentType == 'image' ? '图片' : '文档';
      displayText = trimmed.isEmpty
          ? '[附件: $typeLabel $attachmentName]'
          : '$trimmed\n[附件: $typeLabel $attachmentName]';
    }

    _messages.add(ChatMessage(text: displayText, isUser: true));
    _messages.add(ChatMessage(text: '', isUser: false, isStreaming: true));
    _isLoading = true;

    final pendingFile = _pendingAttachment;
    final pendingType = _pendingAttachmentType;
    _pendingAttachment = null;
    _pendingAttachmentType = '';

    _notify();
    onNeedScroll?.call();

    final storage = MemoryStorage();
    await storage.loadAll();
    final personalization = PersonalizationStorage();
    await personalization.load();

    final systemPrompt = PromptBuilder.buildMainPrompt(
      userName: personalization.userName,
      stylePrompt: personalization.stylePrompt,
      customPrompt: personalization.customPrompt,
      userMessage: trimmed,
      now: DateTime.now(),
    );

    final history = buildMessageHistory(
      systemPrompt: systemPrompt,
      messages: _messages,
      attachmentBase64: attachmentBase64,
      attachmentName: attachmentName,
      pendingType: pendingType,
      text: trimmed,
      pendingFileSize: pendingFile?.lengthSync(),
      maxMessages: 20,
    );

    final ai = AIService(
      baseUrl: _aiSettings.baseUrl,
      apiKey: _aiSettings.apiKey,
      providerName: _aiSettings.selectedVendor?.name ?? '',
      model: _aiSettings.effectiveModel,
      toolRegistry: _toolRegistry,
    );

    final aiMsg = _messages.last;
    final state = _StreamState();
    _currentSteps = state.steps;

    try {
      _aiStream = ai.sendMessageStream(history).listen(
        (event) => _onStreamEvent(event, state, aiMsg),
        onDone: () => _onStreamDone(state, aiMsg),
        onError: (e) => _onStreamError(e, state, aiMsg),
      );
    } catch (e) {
      _onStreamError(e, state, aiMsg);
    }
  }

  void stopStream() {
    _aiStream?.cancel();
    _aiStream = null;
    if (_currentSteps != null) {
      finishRunningSteps(_currentSteps!);
    }
    final aiMsg = _messages.isNotEmpty && !_messages.last.isUser
        ? _messages.last
        : null;
    if (aiMsg != null) {
      aiMsg.isStreaming = false;
      aiMsg.steps = _currentSteps != null ? List.unmodifiable(_currentSteps!) : null;
      if (aiMsg.text.isEmpty) aiMsg.text = '(已停止)';
    }
    _currentSteps = null;
    _isLoading = false;
    _notify();
  }

  // ═══ Stream handling ═══

  void _onStreamEvent(ChatStreamEvent event, _StreamState state, ChatMessage aiMsg) {
    switch (event) {
      case TextChunkEvent(:final text):
        state.buf.write(text);
        if (state.firstChunk) {
          state.firstChunk = false;
          state.steps.add(TimelineStep(
              label: '思考中', type: TimelineStepType.thinking, status: TimelineStepStatus.running));
        }
        break;
      case ToolStartEvent(:final name):
        state.hasToolCalls = true;
        finishRunningSteps(state.steps);
        state.steps.add(TimelineStep(
            label: _toolLabel(name), type: TimelineStepType.tool, status: TimelineStepStatus.running));
        if (name == 'generate_image' || name == 'generate_video') {
          NotificationService().startTask(
              id: name, title: _toolLabel(name), message: '准备中…');
        }
        break;
      case ToolDoneEvent(:final name):
        final idx = state.steps.lastIndexWhere((s) =>
            s.type == TimelineStepType.tool &&
            s.label == _toolLabel(name) &&
            s.status == TimelineStepStatus.running);
        if (idx >= 0) state.steps[idx].status = TimelineStepStatus.done;
        state.steps.add(TimelineStep(
            label: '思考中', type: TimelineStepType.thinking, status: TimelineStepStatus.running));
        if (name == 'generate_image' || name == 'generate_video') {
          NotificationService().complete(
              id: name, title: _toolLabel(name), message: '已完成');
        }
        break;
      case ToolErrorEvent(:final name):
        final idx = state.steps.lastIndexWhere((s) =>
            s.type == TimelineStepType.tool &&
            s.label == _toolLabel(name) &&
            s.status == TimelineStepStatus.running);
        if (idx >= 0) state.steps[idx].status = TimelineStepStatus.error;
        if (name == 'generate_image' || name == 'generate_video') {
          NotificationService().complete(
              id: name, title: _toolLabel(name), message: '执行失败');
        }
        break;
      case ToolMediaEvent(:final url):
        state.buf.write('\n$url\n');
        break;
      case ErrorEvent(:final message):
        state.buf.write('\n\n$message');
        break;
    }
    aiMsg.text = state.buf.toString();
    aiMsg.steps = List.unmodifiable(state.steps);
    _notify();
    onNeedScroll?.call();
  }

  void _onStreamDone(_StreamState state, ChatMessage aiMsg) {
    finishRunningSteps(state.steps);
    if (state.steps.isNotEmpty && state.steps.last.type == TimelineStepType.thinking) {
      state.steps.last.label = '任务完成';
    }
    _currentSteps = null;
    aiMsg.isStreaming = false;
    aiMsg.steps = state.steps.isEmpty ? null : List.unmodifiable(state.steps);
    if (aiMsg.text.isEmpty && !state.hasToolCalls) aiMsg.text = '(无响应)';
    _isLoading = false;
    _notify();
    saveSession();
  }

  void _onStreamError(Object e, _StreamState state, ChatMessage aiMsg) {
    finishRunningSteps(state.steps);
    _currentSteps = null;
    aiMsg.text = state.buf.isEmpty ? '错误: $e' : '${state.buf.toString()}\n\n错误: $e';
    aiMsg.isStreaming = false;
    aiMsg.steps = state.steps.isEmpty ? null : List.unmodifiable(state.steps);
    _isLoading = false;
    _notify();
  }

  String _toolLabel(String name) => toolLabel(name);
}

/// 一次流式响应的临时状态，避免在闭包里维护大量局部变量。
class _StreamState {
  final StringBuffer buf = StringBuffer();
  final List<TimelineStep> steps = [];
  bool firstChunk = true;
  bool hasToolCalls = false;
}
