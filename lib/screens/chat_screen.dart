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
import '../widgets/chat_skeleton.dart';
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
    with WidgetsBindingObserver {
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
  // 会话加载态：initialize 完成前显示骨架屏（仅冷启动/未就绪时），
  // 完成后淡入真实列表，使转场帧与首屏气泡 build 帧错峰。
  bool _loading = false;
  // 点击「回到底部」：原生 animateTo 平滑滚动，不再用 AnimationController 手动循环。
  // 见 _scrollToBottom。
  // 上次键盘遮挡高度：用于在 didChangeMetrics 中判断键盘是否正在弹起。
  double _lastViewInsetBottom = 0;

  @override
  void initState() {
    super.initState();
    // 复用会话控制器缓存：再次进入已打开过的会话时直接复用，消息已在内存、
    // 无需重新从 DB 加载，进入瞬间无白屏/重载闪烁（微信级 L8 页面缓存）。
    _controller = getIt<ChatControllerCache>().obtain(
      widget.sessionId,
      onNeedScroll: _scrollDown,
    );
    // 加载态：有会话 id 且控制器尚未就绪（首开/冷启动）才显示骨架屏；
    // 缓存命中（已 initialized 且消息在内存）直接显示真实列表，不闪骨架。
    _loading = _controller.currentSessionId != null && !_controller.isReady;
    _controller.initialize().then((_) {
      if (mounted) setState(() => _loading = false);
      // 恢复上次离开时的滚动位置（缓存复用场景）
      if (mounted &&
          _controller.lastScrollOffset != null &&
          _scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_controller.lastScrollOffset!);
      }
    });
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // 记录滚动位置供缓存复用恢复
    if (_scrollCtrl.hasClients) {
      _controller.lastScrollOffset = _scrollCtrl.offset;
    }
    // 仅当控制器未被缓存（新建会话）时才 dispose；缓存的由 ChatControllerCache 持有
    if (widget.sessionId == null) _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// 键盘弹起/收起时被系统回调。键盘弹起（viewInsets 增大）且用户本就在底部时，
  /// 让列表跟随键盘同步贴底——否则 Scaffold resize 后列表可视区缩小、最后一条消息
  /// 会被抬高的输入框遮挡。用逐帧 jumpTo 跟随键盘上移动画，最跟手、无二次动画抖动。
  /// 用户上滑看历史（_userScrolledUp）时点输入框不强制拽回底部，保持阅读位置。
  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final inset = MediaQuery.of(context).viewInsets.bottom;
      final opening = inset > _lastViewInsetBottom;
      _lastViewInsetBottom = inset;
      if (!opening || _drawerOpen) return;
      // 键盘弹起时（Scaffold 已 resize 抬起输入框），只要用户本来就在会话底部
      // 附近（正在输入新消息的典型场景），就把列表补贴到底——确保最后一条消息不被
      // 抬起的输入框遮挡。用「距底 < 1 屏」判断，比脆弱的 _userScrolledUp 标志更稳，
      // 且用户明显上翻看历史时（距底很远）不打扰其阅读位置。
      final pos = _scrollCtrl.position;
      final distFromBottom = pos.maxScrollExtent - pos.pixels;
      if (distFromBottom < pos.viewportDimension) {
        _scrollCtrl.jumpTo(pos.maxScrollExtent);
      }
    });
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

  /// 平滑回到底部：用于点击「回到底部」按钮。
  /// 复位 _userScrolledUp 让流式自动贴底能恢复。
  ///
  /// 【顺滑 + 无白屏】距底不超过 cacheExtent 的 ~80%（约 3200px≈4 屏）时直接整体用
  /// 原生 `animateTo` 平滑滚动：该范围内气泡已由 cacheExtent 预构建，沿途无白屏、无
  /// 突兀跳变，最跟手。仅当用户在极远处（>4 屏）点回到底部，才先瞬时 jumpTo 到
  /// 「底部前约 1.5 屏」（只构建最后一屏气泡，避免 animateTo 一路白屏），再对最后一
  /// 小段做平滑动画收尾。旧实现每帧 jumpTo 手动循环 + 1.2 屏即硬跳，导致中距离也有
  /// "先瞬移再滑"的割裂感——此即「回到底部不流畅」的根因。
  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _userScrolledUp = false;
    final pos = _scrollCtrl.position;
    final viewport = pos.viewportDimension;
    final max = pos.maxScrollExtent;
    // 先置位程序滚动守卫，使下方预跳 jumpTo 不被 _onScroll 误判为用户上滑/重复 setState
    _autoScrolling = true;
    const cacheExtentPx = 4000.0; // 与 _MessageList cacheExtent 对齐
    final smoothLimit = (cacheExtentPx * 0.8).clamp(0.0, max);
    if (max - _scrollCtrl.offset > smoothLimit) {
      // 超远：先瞬时跳到「底部前约 1.5 屏」，只构建最后一屏，避免 animateTo 沿途白屏
      final preJump = (max - viewport * 1.5).clamp(0.0, max);
      _scrollCtrl.jumpTo(preJump);
    }
    _scrollCtrl
        .animateTo(
          max,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        )
        .then((_) => _autoScrolling = false)
        .catchError((_) => _autoScrolling = false);
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
    if (id == _controller.currentSessionId) {
      // 已是当前会话：直接关抽屉即可，无需切换
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }
    _resetInput();
    // 【流畅度修正】去掉旧版「260ms 骨架延迟」——那是上一轮为避开抽屉与列表同帧打架
    // 而加的，却带来"点完要等转圈才进"的割裂感。现改为：点会话立即在抽屉关闭动画
    // "背后"切会话。标准 Drawer 不透明、完全覆盖内容，重建被遮挡不可见；抽屉收起时
    // 内容已就绪 → 零人工延迟、无骨架闪烁、无 AnimatedSwitcher 交叉淡入卡点。对齐
    // Operit「抽屉 GPU 动画期间内容不重组 / 切换不卡顿」原则。
    _controller.switchSession(id).then((_) {
      if (mounted) widget.onSessionChanged?.call();
    }).catchError((e, st) {
      debugPrint('切换会话失败: $e');
    });
    _scaffoldKey.currentState?.closeDrawer();
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
          drawerEnableOpenDragGesture: true,
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
                    AnimatedSwitcher(
                      duration: AppDurations.standard,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _loading
                          ? const ChatListSkeleton(key: ValueKey('skeleton'))
                          : _MessageList(
                              key: const ValueKey('list'),
                              controller: _controller,
                              scrollController: _scrollCtrl,
                              onRetry: _onRetry,
                              onDelete: (m) => _controller.deleteMessage(m),
                              onRegenerate: (m) => _controller.regenerate(m),
                            ),
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
    super.key,
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
          cacheExtent: 4000, // 【流畅度·治 B】放大缓存窗口：视口外保留 4000px 气泡，滚回长消息不销毁/不重测 markdown（对齐 Operit 大缓存窗口原则）。原 500px 太小，长消息滚回频繁重建→卡顿。
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

