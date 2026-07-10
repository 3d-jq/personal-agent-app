import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_message.dart';
import '../core/agent_colors.dart';
import '../widgets/agent_side_drawer.dart';
import '../widgets/agent_top_bar.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_identity_button.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_model_chip.dart';
import '../widgets/chat_new_chat_button.dart';
import '../core/app_animations.dart';

class ChatScreen extends StatefulWidget {
  final String? sessionId;
  final VoidCallback? onSessionChanged;
  const ChatScreen({super.key, this.sessionId, this.onSessionChanged});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  late final ChatController _controller;
  bool _pendingScroll = false;
  bool _showScrollBottom = false;
  bool _userScrolledUp = false;
  // 程序主动触发的滚动（点击回到底部 / 流式自动贴底）期间为 true，
  // 避免 _onScroll 把"自己的位移"误判成用户上滑而污染状态
  bool _autoScrolling = false;

  @override
  void initState() {
    super.initState();
    _controller = ChatController(
      initialSessionId: widget.sessionId,
      onNeedScroll: _scrollDown,
    );
    _controller.initialize();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 程序主动滚动期间忽略，避免误判用户上滑
    if (!_scrollCtrl.hasClients || _autoScrolling) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final current = _scrollCtrl.position.pixels;
    final distFromBottom = max - current;
    final shouldShow = distFromBottom > 120;
    if (shouldShow != _showScrollBottom) {
      setState(() => _showScrollBottom = shouldShow);
    }
    if (distFromBottom > 60) {
      _userScrolledUp = true;
    }
  }

  /// 流式期间实时贴底：下一帧布局完成后 jump 到末尾，消除 50ms 节流造成的「定期猛跳」。
  /// 用 [_pendingScroll] 去重，避免每个流式 token 都注册一次 postFrame 回调而堆积。
  void _scrollDown() {
    if (_userScrolledUp || _autoScrolling || _pendingScroll) return;
    _pendingScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScroll = false;
      if (!_scrollCtrl.hasClients || _userScrolledUp || _autoScrolling) return;
      _autoScrolling = true;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      _autoScrolling = false;
    });
  }

  /// 平滑回到底部：用于点击「回到底部」按钮。
  /// 复位 _userScrolledUp 让流式自动贴底能恢复；动画结束后兜底补一次贴底
  /// （流式期间内容可能已增长，避免落点比真实底部高）。
  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _userScrolledUp = false;
    _autoScrolling = true;
    _scrollCtrl
        .animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    )
        .then((_) {
      _autoScrolling = false;
      // 兜底：若动画期间内容增长导致未真正贴底，补一次
      if (_scrollCtrl.hasClients &&
          _scrollCtrl.position.pixels <
              _scrollCtrl.position.maxScrollExtent - 4) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }


  void _handleSend() {
    _userScrolledUp = false;
    final text = _inputCtrl.text;
    if (_controller.isWaitingUserPrompt) {
      _resetInput();
      _controller.submitUserPromptResponse(text);
    } else {
      _resetInput();
      _controller.sendMessage(text);
    }
  }

  void _resetInput() {
    _inputCtrl.clear();
    _inputFocus.unfocus();
  }

  void _onRetry() {
    _controller.resendLast();
  }

  void _onNewChat() async {
    _resetInput();
    await _controller.saveSession();
    _controller.newSession();
    await _controller.refreshSessions();
  }

  void _onSessionTap(String id) {
    if (id != _controller.currentSessionId) {
      _resetInput();
      _controller.switchSession(id).then((_) {
        widget.onSessionChanged?.call();
      }, onError: (e, st) {
        debugPrint('切换会话失败: $e');
      });
    }
  }

  void _onSessionDeleted(String id) async {
    await _controller.deleteSession(id);
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: nc.background,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: GestureDetector(
        onTap: () {
          if (!(_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
            _inputFocus.unfocus();
          }
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: nc.background,
          drawerEnableOpenDragGesture: false,
          drawerScrimColor: Colors.black.withValues(alpha: 0.38),
          drawer: _DrawerContent(
            controller: _controller,
            onSessionTap: _onSessionTap,
            onNewChat: _onNewChat,
            onSessionDeleted: _onSessionDeleted,
          ),
          appBar: AgentTopBar(
            afterMenu: _ModelChip(controller: _controller),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatNewChatButton(controller: _controller, onBeforeNew: _resetInput),
                const SizedBox(width: 8),
                const ChatIdentityButton(),
              ],
            ),
          ),
          resizeToAvoidBottomInset: true,
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _MessageList(
                      controller: _controller,
                      scrollController: _scrollCtrl,
                      onRetry: _onRetry,
                      onDelete: (m) => _controller.deleteMessage(m),
                      onRegenerate: (m) => _controller.regenerate(m),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 12,
                      child: AnimatedOpacity(
                        opacity: _showScrollBottom ? 1.0 : 0.0,
                        duration: AppDurations.fast,
                        curve: Curves.easeOut,
                        child: IgnorePointer(
                          ignoring: !_showScrollBottom,
                          child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _scrollToBottom();
                          },
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: nc.surface.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: nc.divider, width: 0.5),
                                ),
                              child: Icon(Icons.keyboard_arrow_down, size: 18, color: nc.textPrimary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ],
                ),
              ),
              _ChatInputBar(
                controller: _controller,
                inputController: _inputCtrl,
                focusNode: _inputFocus,
                bottomSafe: bottomSafe,
                onSend: _handleSend,
                onResetInput: _resetInput,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerContent extends StatelessWidget {
  final ChatController controller;
  final ValueChanged<String> onSessionTap;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSessionDeleted;

  const _DrawerContent({
    required this.controller,
    required this.onSessionTap,
    required this.onNewChat,
    required this.onSessionDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => AgentSideDrawer(
        sessions: controller.sessions,
        currentSessionId: controller.currentSessionId,
        isLoading: controller.isLoading,
        onSessionTap: onSessionTap,
        onNewChat: onNewChat,
        onSessionDeleted: onSessionDeleted,
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  final ChatController controller;
  const _ModelChip({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.aiSettings,
      builder: (context, child) => ChatModelChip(
        settings: controller.aiSettings,
        onChanged: () {},
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final ChatController controller;
  final ScrollController scrollController;
  final VoidCallback? onRetry;
  final ValueChanged<ChatMessage>? onDelete;
  final ValueChanged<ChatMessage>? onRegenerate;

  const _MessageList({
    required this.controller,
    required this.scrollController,
    this.onRetry,
    this.onDelete,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final nc = AgentColors.of(context);
        return ListView.builder(
          controller: scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          itemCount: controller.messages.length,
          cacheExtent: 500,
          // ChatMessage 是 ChangeNotifier，流式更新时仅对应气泡局部重建；
          // 必须逐条用 ListenableBuilder(msg) 包住，否则流式期间 controller 不通知、气泡不刷新
          itemBuilder: (c, i) {
            final msg = controller.messages[i];
            return ListenableBuilder(
              key: ValueKey(msg.id),
              listenable: msg,
              builder: (_, __) => ChatBubble(
                msg: msg,
                nc: nc,
                onRetry: onRetry,
                onDelete: onDelete == null ? null : () => onDelete!(msg),
                onRegenerate: (onRegenerate == null || msg.isUser)
                    ? null
                    : () => onRegenerate!(msg),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final ChatController controller;
  final TextEditingController inputController;
  final FocusNode focusNode;
  final double bottomSafe;
  final VoidCallback onSend;
  final VoidCallback onResetInput;

  const _ChatInputBar({
    required this.controller,
    required this.inputController,
    required this.focusNode,
    required this.bottomSafe,
    required this.onSend,
    required this.onResetInput,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => ChatInputBar(
        bottomSafe: bottomSafe,
        controller: inputController,
        focusNode: focusNode,
        onSend: onSend,
        onStop: controller.stopStream,
        isLoading: controller.isLoading,
        isCompressing: controller.isCompressing,
        isAwaitingReply: controller.isWaitingUserPrompt,
        settings: controller.aiSettings,
        onChanged: () {},
        pendingFile: controller.pendingAttachment,
        pendingFileType: controller.pendingAttachmentType,
        onAttachment: (file, type) => controller.setAttachment(file, type),
        onClearAttachment: controller.clearAttachment,
      ),
    );
  }
}

