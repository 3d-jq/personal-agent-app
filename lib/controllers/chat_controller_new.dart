import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/service_locator.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/chat_storage.dart';
import '../services/context_doc_service.dart';
import '../widgets/ai_settings_sheet.dart';

/// 单聊页面的业务控制器。
///
/// 负责会话管理、消息发送等；
/// UI 层只负责渲染与输入控件，通过 [ChangeNotifier] 监听状态变化。
class ChatController extends ChangeNotifier {
  ChatController({this.initialSessionId});

  final String? initialSessionId;
  
  // ═══ 私有状态 ═══
  bool _disposed = false;
  bool _isLoading = false;
  String? _sessionId;
  List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];
  File? _pendingAttachment;
  String _pendingAttachmentType = '';

  // ═══ Public getters ═══
  bool get isLoading => _isLoading;
  String? get currentSessionId => _sessionId;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  File? get pendingAttachment => _pendingAttachment;
  String get pendingAttachmentType => _pendingAttachmentType;
  bool get hasAttachment => _pendingAttachment != null;

  // ═══ Lifecycle ═══
  Future<void> initialize() async {
    await getIt<AISettings>().load();
    await _warmUpCaches();
    await _initSessions();
    _notify();
  }

  Future<void> _warmUpCaches() async {
    final contextDocs = getIt<ContextDocService>();
    await contextDocs.ensureDefaults();
    await contextDocs.loadAll();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ═══ Session management ═══
  Future<void> _initSessions() async {
    final chatStorage = getIt<ChatStorage>();
    final allSessions = await chatStorage.loadAll();
    _sessions = allSessions.where((s) => s.type != 'agent').toList();
    final sid = initialSessionId ?? (_sessions.isNotEmpty ? _sessions.first.id : null);
    if (sid != null) {
      await loadSession(sid);
    } else {
      newSession();
    }
  }

  void newSession() {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _messages = [];
    _notify();
  }

  Future<void> loadSession(String id) async {
    _sessionId = id;
    final sessions = await getIt<ChatStorage>().loadAll();
    final session = sessions.where((s) => s.id == id).firstOrNull;
    _messages = session?.messages.toList() ?? [];
    _notify();
  }

  Future<void> saveSession() async {
    if (_sessionId == null || _messages.isEmpty) return;
    final userMsg = _messages.where((m) => m.isUser).firstOrNull;
    final title = userMsg != null
        ? userMsg.text.replaceAll('\n', ' ').substring(0, userMsg.text.length.clamp(0, 30)).trim()
        : '新对话';
    await getIt<ChatStorage>().save(
      ChatSession(
        id: _sessionId!,
        title: title,
        messages: List<ChatMessage>.from(_messages),
        updatedAt: DateTime.now(),
      ),
    );
    await refreshSessions();
  }

  Future<void> switchSession(String id) async {
    await saveSession();
    await loadSession(id);
  }

  Future<void> deleteSession(String id) async {
    await getIt<ChatStorage>().delete(id);
    await refreshSessions();
    if (id == _sessionId) {
      newSession();
    }
  }

  Future<void> refreshSessions() async {
    final allSessions = await getIt<ChatStorage>().loadAll();
    _sessions = allSessions.where((s) => s.type != 'agent').toList();
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
  Future<void> sendUserMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && !hasAttachment) return;

    _messages.add(ChatMessage(
      text: trimmed,
      isUser: true,
      attachmentPath: _pendingAttachment?.path,
      attachmentType: _pendingAttachmentType.isNotEmpty ? _pendingAttachmentType : null,
    ));
    clearAttachment();
    _notify();
  }
}
