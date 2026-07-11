import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_message.dart';
import '../services/chat_controller_cache.dart';
import '../core/service_locator.dart';
import '../core/agent_colors.dart';
import '../widgets/agent_side_drawer.dart';
import '../widgets/agent_top_bar.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_model_chip.dart';
import '../widgets/chat_new_chat_button.dart';
import '../widgets/session_info_button.dart';
import '../core/app_animations.dart';

class ChatScreen extends StatefulWidget {
  final String? sessionId;
  final VoidCallback? onSessionChanged;
  const ChatScreen({super.key, this.sessionId, this.onSessionChanged});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
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
  // Drawer 打开时暂停自动贴底滚动，避免每帧 jumpTo 与 Drawer 动画抢主 isolate 导致卡顿
  bool _drawerOpen = false;
  late final AnimationController _scrollAnim;

  @override
  void initState() {
    super.initState();
    // 复用会话控制器缓存：再次进入已打开过的会话时直接复用，消息已在内存、
    // 无需重新从 DB 加载，进入瞬间无白屏/重载闪烁（微信级 L8 页面缓存）。
    _controller = getIt<ChatControllerCache>().obtain(
      widget.sessionId,
      onNeedScroll: _scrollDown,
    );
    _controller.initialize().then((_) {
      // 恢复上次离开时的滚动位置（缓存复用场景）
      if (mounted &&
          _controller.lastScrollOffset != null &&
          _scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_controller.lastScrollOffset!);
      }
    });
    _scrollCtrl.addListener(_onScroll);
    _scrollAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scrollAnim.addListener(_followBottom);
    _scrollAnim.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _autoScrolling = false;
      }
    });
  }

  @override
  void dispose() {
    // 记录滚动位置供缓存复用恢复
    if (_scrollCtrl.hasClients) {
      _controller.lastScrollOffset = _scrollCtrl.offset;
    }
    // 仅当控制器未被缓存（新建会话）时才 dispose；缓存的由 ChatControllerCache 持有
    if (widget.sessionId == null) _controller.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _scrollAnim.dispose();
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
    // Drawer 打开时暂停自动贴底：避免每帧 jumpTo 与 Drawer 打开动画抢主 isolate
    if (_drawerOpen) return;
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

  /// 跟随式回到底部：每帧 jump 到「当前」maxScrollExtent。
  /// 当列表滚到底部时底部 item 才被布局，真实 max 会比动画起点(估算值)更大；
  /// 旧实现先 animateTo 一个固定目标、结束再 jumpTo 兜底，会在长列表/未布局项上
  /// 产生「先到错误底部、再 snap 到真底部」的可见跳变。改为每帧跟随当前 max，
  /// 底部 item 随布局完成自然把 max 推高，滚动平滑到底、无二次 snap。
  void _followBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    }
  }

  /// 平滑回到底部：用于点击「回到底部」按钮。
  /// 复位 _userScrolledUp 让流式自动贴底能恢复；用跟随式动画代替「animateTo+兜底 jumpTo」。
  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _userScrolledUp = false;
    _autoScrolling = true;
    _scrollAnim.stop();
    _scrollAnim.forward(from: 0);
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
    getIt<ChatControllerCache>().evict(id);
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
          onDrawerChanged: (opened) => _drawerOpen = opened,
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
                SessionInfoButton(
                  getTokens: () => _controller.estimatedContextTokens,
                  getWindowSize: () => _controller.contextWindowSize,
                  getThreshold: () => _controller.contextCompressionThreshold,
                  listenable: _controller,
                ),
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
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: nc.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: nc.divider, width: 0.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(Icons.keyboard_arrow_down, size: 18, color: nc.textPrimary),
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
        final hasOlder = controller.hasOlderMessages;
        final itemCount = controller.messages.length + (hasOlder ? 1 : 0);
        return ListView.builder(
          controller: scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          itemCount: itemCount,
          cacheExtent: 500,
          // ChatMessage 是 ChangeNotifier，流式更新时仅对应气泡局部重建；
          // 必须逐条用 ListenableBuilder(msg) 包住，否则流式期间 controller 不通知、气泡不刷新
          itemBuilder: (c, i) {
            // 顶部「加载更早消息」入口：点击游标分页 prepend 更早的历史
            if (hasOlder && i == 0) {
              return _OlderMessagesHeader(
                onLoad: controller.loadOlderMessages,
              );
            }
            final msg = controller.messages[i - (hasOlder ? 1 : 0)];
            // 每个气泡独立 RepaintBoundary：长列表滚动时只重绘进入/离开视口的
            // 气泡，已离屏/静止气泡不参与重绘，消除整列表滚动时的连带重绘卡顿。
            return RepaintBoundary(
              child: ListenableBuilder(
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
              ),
            );
          },
        );
      },
    );
  }
}

class _OlderMessagesHeader extends StatelessWidget {
  final Future<void> Function() onLoad;
  const _OlderMessagesHeader({required this.onLoad});

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: TextButton.icon(
          onPressed: () => onLoad(),
          icon: Icon(Icons.history, size: 16, color: nc.textSecondary),
          label: Text(
            '加载更早消息',
            style: TextStyle(fontSize: 13, color: nc.textSecondary),
          ),
          style: TextButton.styleFrom(
            backgroundColor: nc.surface.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
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

