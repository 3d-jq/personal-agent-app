import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_message.dart';
import '../services/chat_controller_cache.dart';
import '../core/service_locator.dart';
import '../core/agent_colors.dart';
import '../widgets/agent_top_bar.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_skeleton.dart';
import '../widgets/chat_scroll_to_bottom_button.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_new_chat_button.dart';
import '../widgets/session_info_button.dart';
import '../core/app_animations.dart';
import 'chat_drawer_content.dart';
import 'chat_scroll_mixin.dart';

class ChatScreen extends StatefulWidget {
  final String? sessionId;
  final VoidCallback? onSessionChanged;
  const ChatScreen({super.key, this.sessionId, this.onSessionChanged});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, ChatScrollMixin, TickerProviderStateMixin {
  // 侧边栏平推动画控制器
  late final AnimationController _sidebarCtrl;
  late final Animation<double> _sidebarAnim;
  bool get _sidebarOpen => _sidebarCtrl.isCompleted || _sidebarCtrl.value > 0.5;
  // 拖拽手势内部状态
  double _dragStartX = 0;
  double _dragStartY = 0;
  double _dragStartValue = 0;
  bool _draggingSidebar = false;
  bool _sidebarDragEngaged = false;
  // 发送后滚动定位：将用户消息顶到视口顶部
  final GlobalKey _userAnchorKey = GlobalKey();
  // 用 ValueNotifier 传递标志位（非 widget 参数），
  // 避免 AnimatedSwitcher 因 key 相同而复用旧 widget 实例导致 needsUserAnchor 永为 false。
  final ValueNotifier<bool> _needsUserAnchor = ValueNotifier(false);
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  late final ChatController _controller;
  // 当前消息条数（供 ChatScrollMixin 上滑检测使用）
  @override
  int get messageCount => _controller.messages.length;
  // 当前最后一条消息（供上滑「已读锚点」记录）
  @override
  ChatMessage? get lastMessage =>
      _controller.messages.isEmpty ? null : _controller.messages.last;
  // 全部消息（供「n 条新消息」未读数计算）
  @override
  List<ChatMessage> get allMessages => _controller.messages;
  // 侧边栏切会话的「延迟加载」标志：侧边栏关闭后才显示骨架屏，再执行 DB 加载。
  bool _switching = false;
  // 待切换的会话 id：选中的会话先记下，侧边栏关闭动画结束
  // 的 _onSidebarStatus(dismissed) 里才出骨架屏 + 执行切换。
  String? _pendingSwitchId;
  // 会话加载态：initialize 完成前显示骨架屏（仅冷启动/未就绪时），
  // 完成后淡入真实列表，使转场帧与首屏气泡 build 帧错峰。
  bool _loading = false;
  // 点击「回到底部」：原生 animateTo 平滑滚动，不再用 AnimationController 手动循环。
  // 见 scrollToBottom（ChatScrollMixin）。
  // 上次键盘遮挡高度：用于在 didChangeMetrics 中判断键盘是否正在弹起。
  double _lastViewInsetBottom = 0;

  @override
  void initState() {
    super.initState();
    _sidebarCtrl = AnimationController(
      vsync: this,
      duration: AppDurations.standard,
    );
    _sidebarAnim = CurvedAnimation(
      parent: _sidebarCtrl,
      curve: AppCurves.standard,
    );
    _sidebarCtrl.addListener(() => setState(() {}));
    _sidebarCtrl.addStatusListener(_onSidebarStatus);
    // 复用会话控制器缓存：再次进入已打开过的会话时直接复用，消息已在内存、
    // 无需重新从 DB 加载，进入瞬间无白屏/重载闪烁（微信级 L8 页面缓存）。
    _controller = getIt<ChatControllerCache>().obtain(
      widget.sessionId,
      onNeedScroll: scrollDown,
    );
    // 加载态：有会话 id 且控制器尚未就绪（首开/冷启动）才显示骨架屏；
    // 缓存命中（已 initialized 且消息在内存）直接显示真实列表，不闪骨架。
    _loading = _controller.currentSessionId != null && !_controller.isReady;
    _controller.initialize().then((_) {
      if (mounted) setState(() => _loading = false);
      // 进入会话：定位到最新消息（聊天软件惯例：进会话即见最新），而非恢复上次
      // 离开位置。jumpToLatest 用 post-frame 兜底，避免列表尚未 build 时 hasClients
      // 为 false 导致跳底失效、停在顶部（旧行为即此 bug）。
      jumpToLatest();
    });
    scrollController.addListener(onScroll);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    // 记录滚动位置供缓存复用恢复
    if (scrollController.hasClients) {
      _controller.lastScrollOffset = scrollController.offset;
    }
    // 仅当控制器未被缓存（新建会话）时才 dispose；缓存的由 ChatControllerCache 持有
    if (widget.sessionId == null) _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _inputCtrl.dispose();
    _inputFocus.dispose();
    scrollController.removeListener(onScroll);
    scrollController.dispose();
    super.dispose();
  }

  /// 键盘弹起/收起时被系统回调。键盘弹起（viewInsets 增大）且用户本就在底部时，
  /// 让列表跟随键盘同步贴底——否则 Scaffold resize 后列表可视区缩小、最后一条消息
  /// 会被抬高的输入框遮挡。用逐帧 jumpTo 跟随键盘上移动画，最跟手、无二次动画抖动。
  /// 用户上滑看历史（userScrolledUp）时点输入框不强制拽回底部，保持阅读位置。
  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      final inset = MediaQuery.of(context).viewInsets.bottom;
      final opening = inset > _lastViewInsetBottom;
      _lastViewInsetBottom = inset;
      if (!opening || drawerOpen) return;
      // 键盘弹起时（Scaffold 已 resize 抬起输入框），只要用户本来就在会话底部
      // 附近（正在输入新消息的典型场景），就把列表补贴到底——确保最后一条消息不被
      // 抬起的输入框遮挡。用「距底 < 1 屏」判断，比脆弱的 userScrolledUp 标志更稳，
      // 且用户明显上翻看历史时（距底很远）不打扰其阅读位置。
      final pos = scrollController.position;
      final distFromBottom = pos.maxScrollExtent - pos.pixels;
      if (distFromBottom < pos.viewportDimension) {
        scrollController.jumpTo(pos.maxScrollExtent);
      }
    });
  }

  void _handleSend() {
    userScrolledUp = false;
    final text = _inputCtrl.text;
    if (_controller.isWaitingUserPrompt) {
      _resetInput();
      _controller.submitUserPromptResponse(text);
    } else {
      _resetInput();
      _needsUserAnchor.value = true;
      _controller.sendMessage(text);
    }
    // 发送后将用户消息顶到视口顶部（后续流式回复在下方展开）。
    // sendMessage 内部 _notify() 在微任务中触发，_MessageList 在下帧重建并绑定 GlobalKey。
    // 单层 postFrame：此刻新消息列表已布局完毕，Scrollable.ensureVisible 可直接定位。
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollUserToTop());
  }

  /// 将最后一条用户消息滚动到视口顶部
  void _scrollUserToTop({int retries = 30}) {
    final ctx = _userAnchorKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      // _MessageList 可能尚未重建（contextDocs.loadAll 仍在加载中），
      // 等下一帧重试，最多 30 帧（~500ms）避免死循环。
      if (retries > 0 && _needsUserAnchor.value) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollUserToTop(retries: retries - 1));
      } else {
        _needsUserAnchor.value = false;
      }
      return;
    }
    // 设上滑标志，阻止 scrollDown（流式/错误回调中）在此后覆盖我们的滚动位置。
    userScrolledUp = true;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0, // 0.0 = 顶部对齐
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    _needsUserAnchor.value = false;
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

  /// 侧边栏动画状态变化：关闭完成时先出骨架屏，再执行会话切换。
  void _onSidebarStatus(AnimationStatus status) {
    drawerOpen = status != AnimationStatus.dismissed;
    if (status == AnimationStatus.dismissed && _pendingSwitchId != null) {
      setState(() => _switching = true);
      _performSwitch(_pendingSwitchId!);
      _pendingSwitchId = null;
    }
  }

  void _onSessionTap(String id) {
    if (id == _controller.currentSessionId) {
      _sidebarCtrl.reverse();
      return;
    }
    _resetInput();
    // 不立刻出骨架屏：先关侧边栏动画，等 dismiss 后 _onSidebarStatus 再触发切换
    _pendingSwitchId = id;
    _sidebarCtrl.reverse();
  }

  /// 延迟切会话的实际执行：侧边栏关闭后才跑真正耗时的
  /// [ChatController.switchSession]（DB 读取 + 气泡重建），配合 [_switching]
  /// 驱动的骨架屏，侧边栏关闭后无卡顿。
  Future<void> _performSwitch(String id) async {
    try {
      await _controller.switchSession(id);
    } catch (e) {
      debugPrint('切换会话失败: $e');
    }
    if (!mounted) return;
    setState(() => _switching = false);
    widget.onSessionChanged?.call();
    jumpToLatest();
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
    final sidebarWidth = MediaQuery.of(context).size.width;
    // 铺满全屏
    final pushRange = sidebarWidth;

    final scaffold = Scaffold(
      backgroundColor: nc.background,
      appBar: AgentTopBar(
        onMenuTap: _toggleSidebar,
        afterMenu: ChatModelChipButton(controller: _controller),
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
                  switchInCurve: AppCurves.appear,
                  switchOutCurve: AppCurves.disappear,
                  child: (_loading || _switching)
                      ? ChatListSkeleton(
                          key: const ValueKey('skeleton'),
                          label: _switching ? '加载对话中' : null,
                        )
                      : _MessageList(
                          key: const ValueKey('list'),
                          controller: _controller,
                          scrollController: scrollController,
                          onRetry: _onRetry,
                          onDelete: (m) => _controller.deleteMessage(m),
                          onRegenerate: (m) => _controller.regenerate(m),
                          userAnchorKey: _userAnchorKey,
                          needsUserAnchor: _needsUserAnchor,
                        ),
                ),
                if (showScrollBottom)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (ctx, _) {
                        final last = _controller.messages.isEmpty
                            ? null
                            : _controller.messages.last;
                        return ListenableBuilder(
                          listenable: last ?? const AlwaysStoppedAnimation(0),
                          builder: (_, __) => ChatScrollToBottomButton(
                            unread: userScrolledUp ? unreadCount() : 0,
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await _controller.jumpToLatestPage();
                              jumpToLatest();
                            },
                          ),
                        );
                      },
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
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: nc.background,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: GestureDetector(
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        // OverflowBox 解除父级 800px 约束，让 1480px 的 Row 可以完整布局
        child: OverflowBox(
          maxWidth: double.infinity,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            // 整个画布平移：closed 时主界面居中，open 时侧边栏居中
            offset: Offset(-pushRange + pushRange * _sidebarAnim.value, 0),
            child: SizedBox(
              width: sidebarWidth + pushRange, // 侧边栏(85%) + 主界面(100%)
              child: Row(
                children: [
                  // ── 侧边栏（Row 左孩子，与主界面同一 Z 层）──
                  SizedBox(
                    width: pushRange,
                    child: ChatDrawerContent(
                      controller: _controller,
                      onSessionTap: _onSessionTap,
                      onNewChat: _onNewChat,
                      onSessionDeleted: _onSessionDeleted,
                      onClose: _closeSidebar,
                    ),
                  ),
                  // ── 主界面（Row 右孩子，同一 Z 层）──
                  SizedBox(
                    width: sidebarWidth,
                    child: GestureDetector(
                      onTap: _sidebarOpen
                          ? _closeSidebar
                          : () => _inputFocus.unfocus(),
                      child: scaffold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleSidebar() {
    HapticFeedback.lightImpact();
    if (_sidebarCtrl.isDismissed) {
      _sidebarCtrl.forward();
    } else {
      _sidebarCtrl.reverse();
    }
  }

  void _closeSidebar() {
    if (!_sidebarCtrl.isDismissed) _sidebarCtrl.reverse();
  }

  // ── 拖拽手势：打开（从左边向右拖）/ 关闭（侧边栏上向右拖） ──

  void _onDragStart(DragStartDetails d) {
    _dragStartX = d.globalPosition.dx;
    _dragStartY = d.globalPosition.dy;
    _dragStartValue = _sidebarCtrl.value;
    _sidebarDragEngaged = false;
    _draggingSidebar = _sidebarCtrl.isDismissed || _sidebarOpen;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_draggingSidebar) return;
    final dx = (d.globalPosition.dx - _dragStartX).abs();
    final dy = (d.globalPosition.dy - _dragStartY).abs();
    // 仅当水平移动明显超过垂直移动时才激活侧边栏拖拽，
    // 防止垂直滚动时手指的自然水平漂移误触侧边栏。
    if (!_sidebarDragEngaged) {
      if (dx < 12) return; // 至少 12px 水平移动才算
      if (dx < dy * 0.8) return; // 水平不足垂直 80% → 纯滚动，忽略
      _sidebarDragEngaged = true;
    }
    final w = MediaQuery.of(context).size.width;
    final delta = (d.globalPosition.dx - _dragStartX) / w;
    // 统一逻辑：手指往右 → 值增加，手指往左 → 值减少
    // 关闭态右拉打开，打开态左推关闭
    _sidebarCtrl.value = (_dragStartValue + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_draggingSidebar || !_sidebarDragEngaged) {
      _draggingSidebar = false;
      _sidebarDragEngaged = false;
      return;
    }
    _draggingSidebar = false;
    _sidebarDragEngaged = false;
    final velocity = d.primaryVelocity ?? 0;
    // 快速甩动优先于位置判断（双向对称）：
    // 右甩(>500) → 打开；左甩(<-500) → 关闭；否则过半决定。
    if (velocity > 500) {
      _sidebarCtrl.forward();
    } else if (velocity < -500) {
      _sidebarCtrl.reverse();
    } else if (_sidebarCtrl.value > 0.5) {
      _sidebarCtrl.forward();
    } else {
      _sidebarCtrl.reverse();
    }
  }
}

class _MessageList extends StatelessWidget {
  final ChatController controller;
  final ScrollController scrollController;
  final VoidCallback? onRetry;
  final ValueChanged<ChatMessage>? onDelete;
  final ValueChanged<ChatMessage>? onRegenerate;
  /// 最后一条用户消息的 GlobalKey，用于发送后滚动定位。
  final GlobalKey userAnchorKey;
  /// 是否需要在本次构建时将最后一条用户消息绑定 GlobalKey（通过引用传递，
  /// 避免 AnimatedSwitcher key 复用旧 widget 导致值不更新）。
  final ValueNotifier<bool>? needsUserAnchor;

  const _MessageList({
    super.key,
    required this.controller,
    required this.scrollController,
    this.onRetry,
    this.onDelete,
    this.onRegenerate,
    required this.userAnchorKey,
    this.needsUserAnchor,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final nc = AgentColors.of(context);
        final hasOlder = controller.hasOlderMessages;
        final hasNewer = controller.hasNewerMessages;
        final visible = controller.visibleMessages;
        // 列表长度 = 窗口页条数 + 各方向独立占位（只在确实能翻页时才渲染按钮，不出现灰色不可点状态）。
        final itemCount = visible.length + (hasOlder ? 1 : 0) + (hasNewer ? 1 : 0);
        return ListView.builder(
            controller: scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          itemCount: itemCount,
          cacheExtent: 4000, // 放大缓存窗口：视口外保留 4000px 气泡，滚回不重建
          // ChatMessage 是 ChangeNotifier，流式更新时仅对应气泡局部重建；
          // 必须逐条用 ListenableBuilder(msg) 包住，否则流式期间 controller 不通知、气泡不刷新
          itemBuilder: (c, i) {
            // 顶部「加载更早消息」（仅在有更早内容时渲染，不做灰色不可点占位）
            if (hasOlder && i == 0) {
              return _OlderMessagesHeader(
                onLoad: () async {
                  await controller.loadOlderMessages();
                  if (scrollController.hasClients) {
                    scrollController.jumpTo(0);
                  }
                },
              );
            }
            // 底部「加载最新消息」（仅在有更新内容时渲染，不做灰色不可点占位）
            if (hasNewer && i == itemCount - 1) {
              return _NewerMessagesFooter(
                onLoad: () async {
                  await controller.loadNewerMessages();
                  if (scrollController.hasClients) {
                    // 等列表重建完再跳到底部，否则 maxScrollExtent 还是旧值
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (scrollController.hasClients) {
                        scrollController
                            .jumpTo(scrollController.position.maxScrollExtent);
                      }
                    });
                  }
                },
              );
            }
            // 列表项（当前窗口页）
            final msgIdx = i - (hasOlder ? 1 : 0);
            final msg = visible[msgIdx];
            // 发送后滚动定位：仅当 needsUserAnchor 为 true 且本条是可见列表中的
            // 最后一条用户消息时，将 GlobalKey 绑定到 RepaintBoundary，
            // 供 _scrollUserToTop 通过 Scrollable.ensureVisible 顶到视口顶部。
            final isAnchor = (needsUserAnchor?.value == true) &&
                msg.isUser &&
                !visible.skip(msgIdx + 1).any((m) => m.isUser);
            // 每个气泡独立 RepaintBoundary：长列表滚动时只重绘进入/离开视口的
            // 气泡，已离屏/静止气泡不参与重绘，消除整列表滚动时的连带重绘卡顿。
            return RepaintBoundary(
              key: isAnchor ? userAnchorKey : null,
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
                )
              )
            );
          },
        ); // close ListView.builder, end return
      },
    );
  }
}

class _PagerTile extends StatelessWidget {
  final Future<void> Function()? onLoad;
  final IconData icon;
  final String label;
  const _PagerTile({
    required this.onLoad,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final disabled = onLoad == null;
    final color = disabled ? nc.textDisabled : nc.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: TextButton.icon(
          onPressed: onLoad == null ? null : () => onLoad!(),
          icon: Icon(icon, size: 16, color: color),
          label: Text(
            label,
            style: TextStyle(fontSize: 13, color: color),
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

class _OlderMessagesHeader extends StatelessWidget {
  final Future<void> Function()? onLoad;
  const _OlderMessagesHeader({this.onLoad});

  @override
  Widget build(BuildContext context) => _PagerTile(
        onLoad: onLoad,
        icon: Icons.history,
        label: '加载更早消息',
      );
}

class _NewerMessagesFooter extends StatelessWidget {
  final Future<void> Function()? onLoad;
  const _NewerMessagesFooter({this.onLoad});

  @override
  Widget build(BuildContext context) => _PagerTile(
        onLoad: onLoad,
        icon: Icons.arrow_downward,
        label: '加载最新消息',
      );
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

