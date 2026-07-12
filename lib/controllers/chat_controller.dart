import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/prompt_builder.dart';
import '../core/error_handler.dart';
import '../core/service_locator.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../screens/chat_helpers.dart';
import '../services/ai_service.dart';
import '../services/chat_storage.dart';
import '../services/chat_stream_event.dart';
import '../services/connectivity_service.dart';
import '../services/context_doc_service.dart';
import '../services/history_manager.dart';
import '../services/log_service.dart';
import '../services/notification_service.dart';
import '../services/typewriter_buffer.dart';
import '../tools/tools.dart';
import '../widgets/ai_settings_sheet.dart';
import 'message_window.dart';

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
  }) : _aiSettings = aiSettings ?? getIt<AISettings>(),
       _toolRegistry = toolRegistry ?? ToolRegistry(),
       _chatStorage = chatStorage ?? getIt<ChatStorage>() {
    _window = MessageWindow(_chatStorage, _messages, _notify);
    registerAllTools(_toolRegistry);
    _toolRegistry.register(AskUserTool(onAsk: _onAskUser));
  }

  final String? initialSessionId;
  final AISettings _aiSettings;
  final ToolRegistry _toolRegistry;
  final ChatStorage _chatStorage;

  /// UI 层传入的滚屏回调，控制器不关心 ScrollController。
  /// 非 final：控制器被页面缓存复用时，需重新绑定到新页面的滚屏回调。
  VoidCallback? onNeedScroll;

  /// 对话历史压缩管理器
  HistoryManager? _historyManager;
  HistoryManager get _historyManagerInstance {
    final hm = _historyManager ??= HistoryManager(
      contextWindowSize: _aiSettings.contextWindowSize,
      maxOutputTokens: 4096,
      keepTokens: 8000,
    );
    // 窗口大小可能在 AI 设置中变更，需同步到 HistoryManager——其压缩阈值与
    // 压缩判断都依赖 contextWindowSize。否则改窗口后阈值/节点位置会固化在旧值。
    if (hm.contextWindowSize != _aiSettings.contextWindowSize) {
      hm.contextWindowSize = _aiSettings.contextWindowSize;
    }
    return hm;
  }

  String? _sessionId;
  final List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];
  bool _isLoading = false;
  bool _isCompressing = false;
  /// 已初始化守卫：控制器被 ChatControllerCache 复用时跳过 initialize 的全部
  /// await（settings/warmUp/loadSession），直接复用内存消息，二次进入秒开。
  bool _initialized = false;

  // ── 消息分页（视口滑动窗口，委托给 MessageWindow）──
  late final MessageWindow _window;

  bool get hasOlderMessages => _window.hasOlder;

  /// 页面缓存复用：退出聊天页时记录滚动位置，再次进入时恢复（微信级 L8 页面缓存）。
  double? lastScrollOffset;

  File? _pendingAttachment;
  String _pendingAttachmentType = '';

  StreamSubscription<ChatStreamEvent>? _aiStream;
  List<TimelineStep>? _currentSteps;
  _StreamState? _streamState;

  bool _disposed = false;

  // ═══ Public getters ═══

  String? get currentSessionId => _sessionId;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  bool get isLoading => _isLoading;
  bool get isCompressing => _isCompressing;
  /// 控制器已初始化且已有消息：聊天页进入时可直接显示真实列表，不显示骨架屏。
  bool get isReady => _initialized && _messages.isNotEmpty;
  bool get isWaitingUserPrompt => _streamState?.isWaitingUserInput ?? false;
  File? get pendingAttachment => _pendingAttachment;
  String get pendingAttachmentType => _pendingAttachmentType;
  AISettings get aiSettings => _aiSettings;

  // ── 上下文窗口占用（供 UI 可视化）──
  List<ChatMessage>? _usageMsgRef;
  int _usageMsgLen = -1;
  int _usageLastLen = -1;
  int? _usageTokenCache;
  /// 系统提示（SOUL+USER+rules+skill catalog）估算 token，计入面板占用展示。
  int? _systemPromptTokens;
  /// 上一次计算缓存时「最后一条消息是否在流式」；翻转时强制重算，
  /// 避免「流式结束 isStreaming 翻 false 但文本长度恰好未变」导致缓存不失效、
  /// 面板漏算整条 AI 回复（单聊窄窗口 case，群聊每帧通知下更易触发）。
  bool? _usageLastStreaming;
  /// 当前对话估算占用的 token 数（消息估算 + 系统提示估算，均为字符启发式，非真实分词）。
  /// 带轻量缓存：当消息**列表引用**变更（切会话/压缩）、**条数**变化（新增一轮问答）、
  /// **最后一条内容长度**变化（流式增长）或**最后一条流式状态翻转**（流式收尾）时重算，
  /// 其余无关刷新复用缓存。注意：消息是 `_messages.add(...)` 追加的，列表引用不变，
  /// 故不能只判断引用，否则正常对话中数字永远不刷新。
  int get estimatedContextTokens {
    final last = _messages.isEmpty ? null : _messages.last;
    final lastLen = last?.text.length ?? 0;
    final lastStreaming = last?.isStreaming ?? false;
    if (_usageMsgRef != _messages ||
        _usageMsgLen != _messages.length ||
        _usageLastLen != lastLen ||
        _usageLastStreaming != lastStreaming) {
      _usageMsgRef = _messages;
      _usageMsgLen = _messages.length;
      _usageLastLen = lastLen;
      _usageLastStreaming = lastStreaming;
      _usageTokenCache = _historyManagerInstance.estimateMessagesTokens(_messages);
    }
    return (_usageTokenCache ?? 0) + (_systemPromptTokens ?? 0);
  }
  /// 上下文窗口大小（token 数）。
  int get contextWindowSize => _aiSettings.contextWindowSize;
  /// 触发压缩的 token 阈值。
  int get contextCompressionThreshold => _historyManagerInstance.compressionThreshold;
  /// 占用率（0~1+），估算值。
  double get contextUsageRatio =>
      contextWindowSize > 0 ? estimatedContextTokens / contextWindowSize : 0.0;

  // ═══ Lifecycle ═══

  Future<void> initialize() async {
    if (_initialized) return;
    await _aiSettings.load();
    await _warmUpCaches();
    // 只加载单聊会话
    _sessions = await _chatStorage.loadChatSessions();
    final sid =
        initialSessionId ?? (_sessions.isNotEmpty ? _sessions.first.id : null);
    if (sid != null) {
      await loadSession(sid);
    } else {
      newSession();
    }
    _initialized = true;
    if (!_disposed) _notify();
  }

  /// 预热上下文文档缓存，避免首次发消息时再加载。
  Future<void> _warmUpCaches() async {
    final contextDocs = getIt<ContextDocService>();
    await contextDocs.ensureDefaults();
    await contextDocs.loadAll();
  }

  @override
  void dispose() {
    _disposed = true;
    _aiStream?.cancel();
    _streamState?.typewriterTimer?.cancel();
    _completeUserPrompt('对话已中断');
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ═══ Session management ═══

  void newSession() {
    _sessionId = const Uuid().v4();
    // 【关键】必须原地清空，不能重新赋值 `_messages = []`！
    // MessageWindow 在构造时持有 `_messages` 的引用（见 _window 初始化），
    // 若此处重新赋值一个新列表，MessageWindow 仍指向旧列表，而 `messages`
    // getter 返回新空列表 → 发送的消息进了孤儿列表、UI 读空列表、且
    // `sendMessage` 里 `_messages.last` 在空列表上抛 StateError 导致流不启动。
    // 这正是「发送消息不显示 + 大模型不返回」回归的根因（MessageWindow 拆分引入）。
    _messages.clear();
    _window.reset();
    _notify();
  }

  Future<void> loadSession(String id) async {
    _sessionId = id;
    _window.bindSession(id);
    await _window.load();
    _notify();
  }

  /// 上滑加载更早的消息（游标分页），prepend 到内存窗口头部。
  Future<void> loadOlderMessages() => _window.loadOlder();

  /// 追加一条消息并分配全局序号（保证分页表排序稳定、增量 upsert 不重排）。
  void _appendMessage(ChatMessage msg) => _window.append(msg);

  /// 构造发送给大模型的「全量上下文视图」——与 UI 视口窗口（40 条）完全解耦。
  ///
  /// 以 DB 全量历史为基准（[_window.loadFullHistory]），再合并当前内存中尚未落盘
  /// 的最新消息（如当前轮用户消息），保证模型看到**全部**历史上下文，从而能按 80%
  /// 阈值触发 [HistoryManager] 压缩。UI 窗口 40 条只影响界面显示，绝不参与模型上下文。
  Future<List<ChatMessage>> buildSendView() async {
    if (_sessionId == null) return List.of(_messages);
    final full = await _window.loadFullHistory();
    if (full.isEmpty) return List.of(_messages);
    final lastSeq = full.last.seq;
    // 合并内存中比全量历史更新的、尚未落盘的消息（按全局 seq 判定，避免重复计入）。
    final pending = _messages.where((m) => m.seq > lastSeq).toList();
    if (pending.isEmpty) return full;
    return [...full, ...pending];
  }

  Future<void> saveSession() async {
    if (_sessionId == null || _messages.isEmpty) return;
    final userMsg = _messages.where((m) => m.isUser).firstOrNull;
    final title = userMsg != null
        ? userMsg.text
              .replaceAll('\n', ' ')
              .substring(0, userMsg.text.length.clamp(0, 30))
              .trim()
        : '新对话';
    await _chatStorage.save(
      ChatSession(
        id: _sessionId!,
        title: title,
        messages: List<ChatMessage>.from(_messages),
        updatedAt: DateTime.now(),
      ),
    );
    _sessions = await _chatStorage.loadChatSessions();
    _notify();
  }

  Future<void> switchSession(String id) async {
    // 先停止当前流（stopStream 内部已 saveSession 存盘），再切换，避免流回调
    // 往已替换的消息列表写数据。
    if (_isLoading) {
      stopStream();
    } else if (_sessionId != null && _messages.isNotEmpty) {
      // 【流畅度】已流式收尾的会话此前已在 _finalizeStreamDone 落盘，无需每次切换都
      // 全量序列化全部消息（主线程尖刺 → 抽屉背后重建仍可能被感知为卡顿）。仅轻量
      // 刷新会话列表顺序供抽屉展示。流式进行中才走上面的 stopStream 全量存盘。
      _sessions = await _chatStorage.loadChatSessions();
    }
    await loadSession(id);
  }

  Future<void> deleteSession(String id) async {
    await _chatStorage.delete(id);
    _sessions = await _chatStorage.loadChatSessions();
    if (id == _sessionId) {
      newSession();
    } else {
      _notify();
    }
  }

  Future<void> refreshSessions() async {
    _sessions = await _chatStorage.loadChatSessions();
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

  /// 重发最后一条用户消息（错误气泡「重试」用）：清掉其后所有消息后重新请求。
  Future<void> resendLast() async {
    final idx = _messages.lastIndexWhere((m) => m.isUser);
    if (idx < 0) return;
    final text = _messages[idx].text;
    _messages.removeRange(idx, _messages.length);
    _notify();
    await sendMessage(text);
  }

  /// 删除单条消息（气泡长按菜单「删除」用）。
  Future<void> deleteMessage(ChatMessage msg) async {
    final idx = _messages.indexOf(msg);
    if (idx < 0) return;
    _messages.removeAt(idx);
    if (_sessionId != null) {
      await _chatStorage.deleteMessage(_sessionId!, msg.id);
    }
    _notify();
    await saveSession();
  }

  /// 重新生成某条 AI 回复（气泡长按菜单「重新生成」用）：
  /// 找到该回复前最近的一条用户消息作为 prompt，清掉其后所有内容并重发。
  Future<void> regenerate(ChatMessage aiMsg) async {
    if (_isLoading) return;
    final idx = _messages.indexOf(aiMsg);
    if (idx < 0) return;
    int userIdx = -1;
    for (int i = idx - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        userIdx = i;
        break;
      }
    }
    if (userIdx < 0) return;
    final prompt = _messages[userIdx].text;
    _messages.removeRange(userIdx, _messages.length);
    _notify();
    await sendMessage(prompt);
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (isWaitingUserPrompt) return;
    if ((trimmed.isEmpty && _pendingAttachment == null) || _isLoading) return;
    if (_sessionId == null) newSession();

    _toolRegistry.resetCallCounts();
    // 每次发消息前刷新 MCP 工具，确保新连接的服务器能被大模型发现
    registerMcpTools(_toolRegistry);

    if (!_aiSettings.hasVendor) {
      _appendMessage(ChatMessage(text: '请先配置 AI 后端（点击输入框内存图标）', isUser: false));
      _notify();
      onNeedScroll?.call();
      return;
    }

    if (!await getIt<ConnectivityService>().check()) {
      _appendMessage(ChatMessage(text: '当前无网络连接，请检查网络后重试', isUser: false));
      _notify();
      onNeedScroll?.call();
      return;
    }

    // 同步置位，收窄重入窗口：避免流式首个 await 之前重复触发开第二条流覆盖 _aiStream
    _isLoading = true;

    String displayText = trimmed;
    String? attachmentBase64;
    String? attachmentName;
    if (_pendingAttachment != null) {
      try {
        final bytes = await _pendingAttachment!.readAsBytes();
        attachmentBase64 = base64Encode(bytes);
        attachmentName = _pendingAttachment!.path
            .split(Platform.pathSeparator)
            .last;
        final typeLabel = _pendingAttachmentType == 'image' ? '图片' : '文档';
        displayText = trimmed.isEmpty
            ? '[附件: $typeLabel $attachmentName]'
            : '$trimmed\n[附件: $typeLabel $attachmentName]';
      } catch (e) {
        // 附件读取失败（文件损坏/权限问题）：忽略附件继续发送文本，避免崩溃
        debugPrint('附件读取失败，已忽略: $e');
        attachmentBase64 = null;
        attachmentName = null;
      }
    }

    final contextDocs = getIt<ContextDocService>();
    await contextDocs.loadAll();

    // 首次见面判定：只取决于 USER.md 是否已完成（不依赖消息数）。
    // 去掉原来的 `&& _messages.isEmpty` 一次性门禁——否则首条消息没完成引导后，
    // 后续消息因 _messages 不空而永久不再触发，用户陷入"既不引导、又算没完成"的死区。
    final isFirstMeeting = !contextDocs.hasUserProfile();

    _appendMessage(
      ChatMessage(
        text: displayText,
        isUser: true,
        attachmentPath: _pendingAttachment?.path,
        attachmentType: _pendingAttachmentType.isNotEmpty
            ? _pendingAttachmentType
            : null,
      ),
    );
    _appendMessage(ChatMessage(text: '', isUser: false, isStreaming: true));

    final pendingFile = _pendingAttachment;
    final pendingType = _pendingAttachmentType;
    _pendingAttachment = null;
    _pendingAttachmentType = '';

    _notify();
    onNeedScroll?.call();

    final systemPrompt = PromptBuilder.buildMainPrompt(
      soulContext: contextDocs.cached(ContextDoc.soul),
      userContext: contextDocs.cached(ContextDoc.user),
      isFirstMeeting: isFirstMeeting,
      hasExistingProfile: contextDocs.hasUserProfile(),
    );
    // 系统提示占用计入面板上下文统计（问题：之前只算消息、漏算 SOUL/USER/rules/skill catalog）。
    _systemPromptTokens = _historyManagerInstance.estimateTokens(systemPrompt);

    final ai = AIService(
      baseUrl: _aiSettings.baseUrl,
      apiKey: _aiSettings.apiKey,
      model: _aiSettings.effectiveModel,
      thinkingEffort: _aiSettings.thinkingEffort,
      isAnthropic: _aiSettings.selectedVendor?.isAnthropic ?? false,
      toolRegistry: _toolRegistry,
    );

    // 压缩仅生成「发送时视图」，不替换 _messages、不落盘——完整历史保留在
    // _messages 中供 UI 展示与 saveSession 存盘，用户可随时回溯早期对话。
    // 关键修正：发送视图基于「全量历史」而非 UI 视口窗口（40 条）。UI 窗口只影响
    // 界面显示以省性能，与模型上下文无关；模型必须看到全部历史，才能按 80% 阈值
    // 触发压缩（否则窗口 40 条永远到不了阈值，压缩形同虚设）。
    List<ChatMessage> sendView = await buildSendView();
    try {
      _isCompressing = true;
      _notify();
      final compressed = await _historyManagerInstance.compressIfNeeded(
        sendView,
        ai.summarize,
        systemPromptTokens: _historyManagerInstance.estimateTokens(systemPrompt),
      );
      if (!identical(compressed, sendView)) {
        sendView = compressed;
      }
    } catch (e) {
      log.w('ChatController', 'Compression failed, sending full history', e);
    } finally {
      _isCompressing = false;
      _notify();
    }

    final history = buildMessageHistory(
      systemPrompt: systemPrompt,
      messages: sendView,
      now: DateTime.now(),
      attachmentBase64: attachmentBase64,
      attachmentName: attachmentName,
      attachmentPath: pendingFile?.path,
      pendingType: pendingType,
      text: trimmed,
      pendingFileSize: pendingFile?.lengthSync(),
    );

    final aiMsg = _messages.last;
    final state = _StreamState();
    _streamState = state;
    _currentSteps = state.steps;

    try {
      _aiStream = ai
          .sendMessageStream(history)
          .listen(
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
    _streamState?.typewriterTimer?.cancel();
    _streamState?.typewriterTimer = null;
    _completeUserPrompt('用户取消了当前操作');
    if (_currentSteps != null) {
      finishRunningSteps(_currentSteps!);
    }
    final aiMsg = _messages.isNotEmpty && !_messages.last.isUser
        ? _messages.last
        : null;
    if (aiMsg != null) {
      aiMsg.isStreaming = false;
      aiMsg.steps = _currentSteps != null
          ? List.unmodifiable(_currentSteps!)
          : null;
      if (aiMsg.text.isEmpty) aiMsg.text = '(已停止)';
    }
    _currentSteps = null;
    _isLoading = false;
    _notify();
    // 停止后立即存盘，保留已生成的内容
    saveSession();
  }

  // ═══ Stream handling ═══

  void _onStreamEvent(
    ChatStreamEvent event,
    _StreamState state,
    ChatMessage aiMsg,
  ) {
    switch (event) {
      case ThinkingChunkEvent(:final text):
        state.reasoningBuf.write(text);
        if (state.firstChunk) {
          state.firstChunk = false;
          state.steps.add(
            TimelineStep(
              label: '思考中',
              type: TimelineStepType.thinking,
              status: TimelineStepStatus.running,
            ),
          );
        }
        break;
      case TextChunkEvent(:final text):
        if (state.firstChunk) {
          state.firstChunk = false;
          state.thinkingStepBufStart = 0; // 第一个思考步从 buf 起始处开始截取
          state.steps.add(
            TimelineStep(
              label: '思考中',
              type: TimelineStepType.thinking,
              status: TimelineStepStatus.running,
            ),
          );
        }
        state.buf.write(text);
        _appendTypewriterText(state, aiMsg, text);
        break;
      case ToolStartEvent(:final name, :final id, :final concurrentCount, :final arguments):
        state.hasToolCalls = true;
        _captureThinkingDetail(state);
        _finishThinkingSteps(state.steps);
        final detailLabel = toolLabel(name, arguments: arguments, detailed: true);
        // 并发批次：仅在本批次「最后一个」并发工具上标注 ×N，避免 N 行都写 ×N 造成 N×N 错觉
        final isConcurrent = concurrentCount > 1;
        state._concurrentStarted += 1;
        final isLastInGroup =
            isConcurrent && state._concurrentStarted >= concurrentCount;
        final suffix = isLastInGroup ? ' ×$concurrentCount' : '';
        state.steps.add(
          TimelineStep(
            label: '$detailLabel$suffix',
            type: TimelineStepType.tool,
            status: TimelineStepStatus.running,
            detail: '工具: $name',
            toolId: id,
          ),
        );
        if (isLastInGroup) state._concurrentStarted = 0;
        _startToolMediaNotification(name);
        break;
      case ToolDoneEvent(:final id, :final name):
        _markToolStep(state.steps, id, TimelineStepStatus.done, '执行成功');
        _resetConcurrentCounterIfDone(state);
        _notifyToolMedia(name, success: true);
        break;
      case ToolErrorEvent(:final id, :final name, :final message):
        _markToolStep(state.steps, id, TimelineStepStatus.error, message);
        _resetConcurrentCounterIfDone(state);
        _notifyToolMedia(name, success: false);
        break;
      case ToolMediaEvent(:final url):
        final text = '\n$url\n';
        state.buf.write(text);
        _appendTypewriterText(state, aiMsg, text);
        break;
      case ToolInteractionEvent(:final toolCalls, :final toolResults):
        state.toolInteractions.add({
          'toolCalls': toolCalls,
          'toolResults': toolResults,
        });
        break;
      case TaskPlanEvent(:final title, :final tasks, :final verified):
        aiMsg.plan = TaskPlan(
          title: title,
          verified: verified,
          tasks: tasks
              .map(
                (t) => TaskNode(
                  id: t.id,
                  title: t.title,
                  status: t.done
                      ? TaskStatus.done
                      : t.inProgress
                      ? TaskStatus.inProgress
                      : TaskStatus.pending,
                ),
              )
              .toList(),
        );
        break;
      case ErrorEvent(:final message):
        final text = '\n\n$message';
        state.buf.write(text);
        _appendTypewriterText(state, aiMsg, text);
        break;
    }
    aiMsg.text = state.typewriter.visibleText;
    aiMsg.steps = List.unmodifiable(state.steps);
    // 文本/步骤变化已由 ChatMessage(ChangeNotifier) 局部通知气泡，
    // 这里不再 _notify() 触发整个消息列表重建（消除流式期间冗余双通知）。
    onNeedScroll?.call();
  }

  void _appendTypewriterText(
    _StreamState state,
    ChatMessage aiMsg,
    String text,
  ) {
    state.typewriter.append(text);
    _ensureTypewriterTimer(state, aiMsg);
  }

  void _ensureTypewriterTimer(_StreamState state, ChatMessage aiMsg) {
    if (state.typewriterTimer != null) return;
    state.typewriterTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!state.typewriter.hasPending) {
        state.typewriterTimer?.cancel();
        state.typewriterTimer = null;
        if (state.streamEnded && !state.finalized) {
          _finalizeStreamDone(state, aiMsg);
        }
        return;
      }
      state.typewriter.revealNext();
      aiMsg.text = state.typewriter.visibleText;
      // aiMsg 自身是 ChangeNotifier，_AIBubble 已监听它做局部刷新，
      // 这里不再需要触发 Controller 全局重建。
      onNeedScroll?.call();
    });
  }

  // ═══ Ask user handling ═══

  Future<String> _onAskUser(String prompt) async {
    final state = _streamState;
    final aiMsg = _messages.isNotEmpty && !_messages.last.isUser
        ? _messages.last
        : null;
    if (state == null || aiMsg == null) {
      return '无法询问用户：当前不在有效的 AI 响应流程中';
    }

    state.isWaitingUserInput = true;
    // 将当前正在运行的工具步骤改写为“等待用户输入”，用户可直接看到阻塞原因
    final stepIdx = state.steps.lastIndexWhere(
      (s) =>
          s.type == TimelineStepType.tool &&
          s.status == TimelineStepStatus.running,
    );
    if (stepIdx >= 0) {
      state.steps[stepIdx].label = '等待用户输入';
    }

    state.buf.write('\n\n---\n💬 $prompt\n\n');
    aiMsg.text = state.buf.toString();
    _isLoading = false;
    _notify();
    onNeedScroll?.call();

    final completer = Completer<String>();
    state.userPromptCompleter = completer;
    return completer.future;
  }

  void submitUserPromptResponse(String response) {
    final state = _streamState;
    if (state == null || state.userPromptCompleter == null) return;

    final trimmed = response.trim();
    if (trimmed.isEmpty) return;

    _isLoading = true;
    _completeUserPrompt(trimmed);
    _notify();
  }

  void _completeUserPrompt(String response) {
    final state = _streamState;
    final completer = state?.userPromptCompleter;
    if (completer == null || completer.isCompleted) return;

    state!.userPromptCompleter = null;
    state.isWaitingUserInput = false;
    completer.complete(response);
  }

  /// 将当前尚未结束的思考步的增量文本截取为 detail。
  /// 应在 finishRunningSteps 之前调用。
  void _captureThinkingDetail(_StreamState state) {
    if (state.steps.isEmpty) return;
    final last = state.steps.last;
    if (last.type != TimelineStepType.thinking ||
        last.status != TimelineStepStatus.running) {
      return;
    }

    // 优先用大模型的 reasoning_content，否则用正文增量作为兜底
    String text;
    if (state.reasoningBuf.isNotEmpty) {
      text = state.reasoningBuf.toString().trim();
    } else {
      final start = state.thinkingStepBufStart;
      final end = state.buf.length;
      if (start >= end) return;
      text = state.buf.toString().substring(start, end).trim();
    }
    if (text.isNotEmpty) {
      last.detail = text.length > 300 ? '${text.substring(0, 300)}…' : text;
    }
  }

  void _onStreamDone(_StreamState state, ChatMessage aiMsg) {
    // 如果 ask_user 正在等待用户输入，流不能算结束
    if (state.isWaitingUserInput) return;

    state.streamEnded = true;
    if (state.typewriter.hasPending) {
      _ensureTypewriterTimer(state, aiMsg);
      return;
    }
    _finalizeStreamDone(state, aiMsg);
  }

  void _finalizeStreamDone(_StreamState state, ChatMessage aiMsg) {
    if (state.finalized) return;
    state.finalized = true;
    state.typewriterTimer?.cancel();
    state.typewriterTimer = null;

    _captureThinkingDetail(state);
    finishRunningSteps(state.steps);
    final plan = aiMsg.plan;
    final allDoneOrFailed =
        plan != null &&
        plan.tasks.every(
          (t) => t.status == TaskStatus.done || t.status == TaskStatus.failed,
        );
    final waitingVerify = allDoneOrFailed && !plan.verified;
    if (state.steps.isNotEmpty) {
      if (state.steps.last.type == TimelineStepType.thinking) {
        state.steps.last.label = waitingVerify ? '等待校验' : '任务完成';
      } else {
        // 最后一步是工具时，追加完成标记
        state.steps.add(
          TimelineStep(
            label: waitingVerify ? '等待校验' : '任务完成',
            type: TimelineStepType.thinking,
            status: TimelineStepStatus.done,
          ),
        );
      }
    }
    _currentSteps = null;
    _streamState = null;
    aiMsg.isStreaming = false;
    aiMsg.text = state.typewriter.visibleText;
    aiMsg.steps = state.steps.isEmpty ? null : List.unmodifiable(state.steps);
    // 持久化工具交互记录到消息历史
    if (state.toolInteractions.isNotEmpty) {
      aiMsg.toolInteractions = state.toolInteractions;
    }
    if (aiMsg.text.isEmpty && !state.hasToolCalls) {
      aiMsg.text = state.reasoningBuf.isNotEmpty
          ? '模型思考时间过长，连接已断开，请重试'
          : '(无响应)';
    }
    _isLoading = false;
    _notify();
    saveSession();
  }

  void _onStreamError(Object e, _StreamState state, ChatMessage aiMsg) {
    state.typewriterTimer?.cancel();
    state.typewriterTimer = null;
    state.typewriter.revealAll();
    _captureThinkingDetail(state);
    finishRunningSteps(state.steps);
    _currentSteps = null;
    _streamState = null;
    aiMsg.isError = true;
    aiMsg.text = ErrorHandler.humanizeError(e);
    aiMsg.isStreaming = false;
    aiMsg.steps = state.steps.isEmpty ? null : List.unmodifiable(state.steps);
    _isLoading = false;
    _notify();
    // 出错后也存盘，保留出错前已生成的内容
    saveSession();
  }

  String _toolLabel(String name) => toolLabel(name);

  /// 将正在运行、且匹配 [id] 的工具步骤更新为 [status] / [detail]。
  ///
  /// 按工具调用唯一 id 精确匹配，避免同批次同名工具互相错配；
  /// 用于 ToolDone / ToolError 事件复用同一查找逻辑。
  void _markToolStep(
    List<TimelineStep> steps,
    String id,
    TimelineStepStatus status,
    String detail,
  ) {
    final idx = steps.lastIndexWhere(
      (s) =>
          s.type == TimelineStepType.tool &&
          s.status == TimelineStepStatus.running &&
          s.toolId == id,
    );
    if (idx >= 0) {
      steps[idx].status = status;
      steps[idx].detail = detail;
    }
  }

  /// 当已无正在运行的工具步骤时，重置并发批次计数，
  /// 以便下一个并发批次能重新在末尾标注 ×N。
  void _resetConcurrentCounterIfDone(_StreamState state) {
    final stillRunning = state.steps.any(
      (s) => s.type == TimelineStepType.tool && s.status == TimelineStepStatus.running,
    );
    if (!stillRunning) state._concurrentStarted = 0;
  }

  /// 图片 / 视频生成工具开始时推送一条"准备中"通知。
  void _startToolMediaNotification(String name) {
    if (name == 'generate_image' || name == 'generate_video') {
      getIt<NotificationService>().startTask(
        id: name,
        title: _toolLabel(name),
        message: '准备中…',
      );
    }
  }

  /// 图片 / 视频生成工具结束（成功或失败）时收尾通知。
  void _notifyToolMedia(String name, {required bool success}) {
    if (name == 'generate_image' || name == 'generate_video') {
      getIt<NotificationService>().complete(
        id: name,
        title: _toolLabel(name),
        message: success ? '已完成' : '执行失败',
      );
    }
  }

  /// 只结束 running 状态的「思考」步骤，不影响正在并行执行的工具步骤。
  void _finishThinkingSteps(List<TimelineStep> steps) {
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].type == TimelineStepType.thinking &&
          steps[i].status == TimelineStepStatus.running) {
        steps[i].status = TimelineStepStatus.done;
      }
    }
  }
}

/// 一次流式响应的临时状态，避免在闭包里维护大量局部变量。
class _StreamState {
  final StringBuffer buf = StringBuffer();
  final TypewriterBuffer typewriter = TypewriterBuffer(charsPerTick: 4);
  Timer? typewriterTimer;
  bool streamEnded = false;
  bool finalized = false;

  /// 大模型内部推理内容（reasoning_content），不显示在正文中。
  final StringBuffer reasoningBuf = StringBuffer();
  final List<TimelineStep> steps = [];
  bool firstChunk = true;
  bool hasToolCalls = false;
  bool isWaitingUserInput = false;
  Completer<String>? userPromptCompleter;

  /// 当前思考步创建时 buf 的长度，用于结束思考步时截取增量文本作为 detail。
  int thinkingStepBufStart = 0;

  /// 当前并发工具批次中已开始的工具数，用于在「批次最后一个」步骤上标注 ×N。
  int _concurrentStarted = 0;

  /// 收集所有轮次的工具交互记录，用于持久化到消息历史。
  final List<Map<String, dynamic>> toolInteractions = [];
}
