import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/agent_colors.dart';
import '../core/design_tokens.dart';
import '../widgets/common_widgets.dart';
import '../core/service_locator.dart';
import '../models/agent.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/agent_runner.dart';
import '../services/chat_storage.dart';
import '../services/chat_stream_event.dart';
import '../services/typewriter_buffer.dart';
import '../tools/tools.dart';
import '../widgets/ai_settings_sheet.dart';
import '../widgets/chat_bubble.dart';
import '../core/error_handler.dart';
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
    // 查找是否已有会话（列表只存元数据，消息体按需加载）
    final sessions = await _chatStorage.loadAll();
    final existing = sessions.where((s) => s.title == widget.agent.name).firstOrNull;
    if (existing != null) {
      final full = await _chatStorage.loadSession(existing.id);
      setState(() {
        _sessionId = existing.id;
        _messages = full?.messages ?? [];
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
      final session = await _chatStorage.loadSession(_sessionId!);
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
      final cfgMsg = ChatMessage(text: '请先在设置中配置 AI 后端', isUser: false);
      cfgMsg.isError = true;
      setState(() {
        _messages.add(cfgMsg);
        _busy = false;
      });
      return;
    }

    // 每次发消息前刷新 MCP 工具
    registerMcpTools(_baseRegistry);

    final placeholder = ChatMessage(
      text: '',
      isUser: false,
      speakerId: widget.agent.id,
      isStreaming: true,
    );
    setState(() => _messages.add(placeholder));
    _scrollDown();

    final buf = StringBuffer();
    final typewriter = TypewriterBuffer(charsPerTick: 4);
    Timer? typewriterTimer;
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
            typewriter.append(event.text);
          }
          // ChatMessage 是 ChangeNotifier，text 赋值即通知气泡的 ListenableBuilder 局部重建，
          // 无需整屏 setState。
          placeholder.text = typewriter.visibleText;
          _scrollDown();

          // 启动打字机定时器
          typewriterTimer ??= Timer.periodic(const Duration(milliseconds: 24), (_) {
              if (!typewriter.hasPending) {
                typewriterTimer?.cancel();
                typewriterTimer = null;
                return;
              }
              typewriter.revealNext();
              placeholder.text = typewriter.visibleText;
              _scrollDown();
            });
        },
        onDone: () {
          typewriterTimer?.cancel();
          typewriterTimer = null;
          typewriter.revealAll();
          placeholder.text = typewriter.visibleText;
          completer.complete();
        },
        onError: (e) {
          typewriterTimer?.cancel();
          typewriterTimer = null;
          final friendly = ErrorHandler.humanizeError(e);
          buf.write('\n\n$friendly');
          typewriter.append('\n\n$friendly');
          typewriter.revealAll();
          placeholder.text = typewriter.visibleText;
          placeholder.isError = true;
          completer.complete();
        },
        cancelOnError: true,
      );
      // 超时保护：防止流挂死导致界面永久卡住
      await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          typewriter.append('\n\n[连接超时，请重试]');
          typewriter.revealAll();
          placeholder.text = typewriter.visibleText;
        },
      );
    } finally {
      await sub?.cancel();
      typewriterTimer?.cancel();
      placeholder.isStreaming = false;
      // 界面可能已返回销毁，setState 前必须校验 mounted，否则抛异常
      if (mounted) setState(() => _busy = false);
      await _saveSession();
    }
  }

  void _stop() {
    _stopped = true;
    setState(() => _busy = false);
  }

  /// 流式过程中返回：不中断模型，让它后台继续跑完，由 _runAgent 的 finally 存盘。
  Future<void> _handleBack() async {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom;

      return PopScope(
        // 允许随时返回：模型在后台继续跑，结束后由 _runAgent 的 finally 存盘
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
      child: Scaffold(
      backgroundColor: nc.background,
      appBar: AppTopBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: nc.textPrimary, size: 22),
          onPressed: _handleBack,
          tooltip: '返回',
        ),
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: nc.primarySurface,
                borderRadius: BorderRadius.circular(RadiusToken.sm),
                border: Border.all(color: nc.divider, width: 0.5),
              ),
              child: Text(
                widget.agent.avatar.isNotEmpty
                    ? widget.agent.avatar
                    : widget.agent.name.characters.first,
                style: TextStyle(
                  fontSize: FontToken.body,
                  fontWeight: WeightToken.semibold,
                  color: nc.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: SpaceToken.sm),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.agent.name,
                  style: TextStyle(
                    fontSize: FontToken.title,
                    fontWeight: WeightToken.semibold,
                    color: nc.textPrimary,
                  ),
                ),
                Text(
                  widget.agent.role,
                  style: TextStyle(
                    fontSize: FontToken.caption,
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: nc.primary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '开始和${widget.agent.name}聊天吧~',
                            style: TextStyle(
                              fontSize: 16,
                              color: nc.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    cacheExtent: 1000, // 缓存窗口：视口外多保留 1000px 的气泡，滚回长消息不重建/重测
                    itemCount: _messages.length,
                    // ChatMessage 是 ChangeNotifier，流式更新时仅对应气泡局部重建
                    itemBuilder: (c, i) => ListenableBuilder(
                      listenable: _messages[i],
                      builder: (_, __) => ChatBubble(msg: _messages[i], nc: nc),
                    ),
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
    ),
    );
  }
}
