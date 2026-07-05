import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/agent_colors.dart';
import '../core/service_locator.dart';
import '../models/agent.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/agent_runner.dart';
import '../services/ai_service.dart';
import '../services/chat_storage.dart';
import '../services/chat_stream_event.dart';
import '../tools/tools.dart';
import '../widgets/ai_settings_sheet.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import 'chat_helpers.dart';

/// Agent 单聊页面
class AgentChatScreen extends StatefulWidget {
  final Agent agent;
  const AgentChatScreen({super.key, required this.agent});

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  final AISettings _aiSettings = getIt<AISettings>();
  final ChatStorage _chatStorage = getIt<ChatStorage>();
  late final AgentRunner _runner;
  late final ToolRegistry _baseRegistry;

  List<ChatMessage> _messages = [];
  String? _sessionId;
  bool _busy = false;
  bool _stopped = false;
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _baseRegistry = ToolRegistry();
    if (_baseRegistry.all.isEmpty) registerAllTools(_baseRegistry);
    _runner = AgentRunner(baseRegistry: _baseRegistry);
    _aiSettings.load();
    _loadSession();
  }

  Future<void> _loadSession() async {
    // 查找是否已有会话
    final sessions = await _chatStorage.loadAll();
    final existing = sessions.where((s) => s.title == widget.agent.name).firstOrNull;
    if (existing != null) {
      setState(() {
        _sessionId = existing.id;
        _messages = existing.messages;
      });
      _scrollDown();
    }
  }

  Future<void> _saveSession() async {
    if (_messages.isEmpty) return;

    if (_sessionId == null) {
      // 创建新会话
      final session = ChatSession(
        id: const Uuid().v4(),
        title: widget.agent.name,
        messages: _messages,
        type: 'agent',
      );
      await _chatStorage.save(session);
      _sessionId = session.id;
    } else {
      // 更新现有会话
      final sessions = await _chatStorage.loadAll();
      final session = sessions.where((s) => s.id == _sessionId).firstOrNull;
      if (session != null) {
        session.messages = _messages;
        session.updatedAt = DateTime.now();
        await _chatStorage.save(session);
      }
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    _scrollTimer?.cancel();
    super.dispose();
  }

  void _scrollDown() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(milliseconds: 80), () {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _busy) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _inputCtrl.clear();
      _inputFocus.unfocus();
      _busy = true;
    });
    _scrollDown();
    await _saveSession();

    await _runAgent();
  }

  Future<void> _runAgent() async {
    final vendor = _aiSettings.selectedVendor ??
        (_aiSettings.vendors.isNotEmpty ? _aiSettings.vendors.first : null);
    if (vendor == null || vendor.apiKey.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(text: '请先在设置中配置 AI 后端', isUser: false));
        _busy = false;
      });
      return;
    }

    final placeholder = ChatMessage(
      text: '',
      isUser: false,
      speakerId: widget.agent.id,
      isStreaming: true,
    );
    setState(() => _messages.add(placeholder));
    _scrollDown();

    final buf = StringBuffer();
    StreamSubscription<ChatStreamEvent>? sub;
    try {
      final stream = _runner.run(
        agent: widget.agent,
        vendor: vendor,
        groupMessages: _messages,
        memberNames: [widget.agent.name],
        speakerNames: {widget.agent.id: widget.agent.name},
        memberRoles: {widget.agent.name: widget.agent.role},
        thinkingEffort: _aiSettings.thinkingEffort,
      );
      final completer = Completer<void>();
      sub = stream.listen(
        (event) {
          if (_stopped) {
            sub?.cancel();
            completer.complete();
            return;
          }
          if (event is TextChunkEvent) {
            buf.write(event.text);
          }
          placeholder.text = buf.toString();
          if (mounted) setState(() {});
          _scrollDown();
        },
        onDone: () => completer.complete(),
        onError: (e) {
          buf.write('\n\n[错误: $e]');
          placeholder.text = buf.toString();
          completer.complete();
        },
        cancelOnError: true,
      );
      await completer.future;
    } finally {
      await sub?.cancel();
      placeholder.isStreaming = false;
      setState(() => _busy = false);
      await _saveSession();
    }
  }

  void _stop() {
    _stopped = true;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: nc.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIconsRegular.arrowLeft, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: nc.primarySurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: nc.divider, width: 0.5),
              ),
              child: Text(
                widget.agent.avatar.isNotEmpty
                    ? widget.agent.avatar
                    : widget.agent.name.characters.first,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: nc.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.agent.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: nc.textPrimary,
                  ),
                ),
                Text(
                  widget.agent.role,
                  style: TextStyle(
                    fontSize: 11,
                    color: nc.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        '开始和${widget.agent.name}聊天吧~',
                        style: TextStyle(color: nc.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (c, i) => ChatBubble(msg: _messages[i], nc: nc),
                  ),
          ),
          ChatInputBar(
            bottomSafe: bottomSafe,
            controller: _inputCtrl,
            focusNode: _inputFocus,
            onSend: _send,
            onStop: _stop,
            isLoading: _busy,
            settings: _aiSettings,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}
