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
    with WidgetsBindingObserver, ChatScrollMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  late final ChatController _controller;
  // 当前消息条数（供 ChatScrollMixin 上滑检测使用）
  @override
  int get messageCount => _controller.messages.length;
  // 侧边栏切会话的「延迟加载」标志：true 时显示「加载对话中」骨架屏，
  // 把真正耗时的 switchSession（DB 加载 + 气泡重建）推迟到抽屉关闭动画结束后再跑。
  bool _switching = false;
  // 待切换的会话 id：点选抽屉里的对话时先记下，待抽屉关闭动画结束（onDrawerChanged
  // 回调）再执行真正耗时的 switchSession。空值同时防御「pop + closeDrawer」双触发。
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

  void _onDrawerChanged(bool opened) {
    drawerOpen = opened;
    // 抽屉关闭动画结束时（closeDrawer() 路径）触发切换；Navigator.pop 路径下该回调
    // 可能不触发，由 _onSessionTap 里的兜底定时器保证执行。_pendingSwitchId 空值
    // 防御「回调 + 定时器」双触发，且只在确有 pending 切会话时执行。
    if (!opened && _switching && _pendingSwitchId != null) {
      _triggerPendingSwitch();
    }
  }

  void _onSessionTap(String id) {
    if (id == _controller.currentSessionId) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }
    _resetInput();
    // 关键优化：点开对话时立刻切到「加载对话中」骨架屏，让抽屉关闭动画期间
    // 不重建真实列表（40 条气泡）。真正耗时的 switchSession（DB 加载 + 气泡重建）
    // 推迟到抽屉关闭动画结束后再执行，从根本上消除「抽屉返回动画」与「列表重建」
    // 同帧竞争导致的卡顿（延迟加载 + 转场动画错峰）。
    // 双触发保证稳健：抽屉关闭动画结束（onDrawerChanged 回调）触发切换；同时起一个
    // 兜底定时器（抽屉关闭动画标准时长附近），即使该回调因关闭路径差异未触发也能切。
    // _pendingSwitchId 空值检查防御「回调 + 定时器」双触发。
    setState(() => _switching = true);
    _pendingSwitchId = id;
    _scaffoldKey.currentState?.closeDrawer();
    // 兜底定时器：最迟在抽屉关闭动画结束附近执行切换，不依赖单一回调路径。
    Future.delayed(AppDurations.expressive, _triggerPendingSwitch);
  }

  /// 触发待切换会话：仅在确有 pending id 时执行，并立即清空，防御双触发。
  void _triggerPendingSwitch() {
    final id = _pendingSwitchId;
    if (id == null) return;
    _pendingSwitchId = null;
    _performSwitch(id);
  }

  /// 延迟切会话的实际执行：抽屉关闭动画结束后才跑真正耗时的
  /// [ChatController.switchSession]（DB 读取 + 40 条气泡重建），配合 [_switching]
  /// 驱动的骨架屏，抽屉滑动丝滑无卡顿。
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
          onDrawerChanged: _onDrawerChanged,
          drawerScrimColor: nc.drawerScrim,
          drawer: ChatDrawerContent(
            controller: _controller,
            onSessionTap: _onSessionTap,
            onNewChat: _onNewChat,
            onSessionDeleted: _onSessionDeleted,
          ),
          appBar: AgentTopBar(
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
                            ),
                    ),
                    ...(showScrollBottom
                        ? [
                            () {
                              final unread = userScrolledUp
                                  ? (_controller.messages.length -
                                          msgCountWhenScrolledUp)
                                      .clamp(0, 999)
                                  : 0;
                              return Positioned(
                                right: 16,
                                bottom: 12,
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    msgCountWhenScrolledUp =
                                        _controller.messages.length;
                                    scrollToBottom();
                                  },
                                  child: AnimatedContainer(
                                    duration: AppDurations.fast,
                                    curve: AppCurves.appear,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: unread > 0 ? 16 : 0,
                                      vertical: unread > 0 ? 10 : 0,
                                    ),
                                    decoration: unread > 0
                                        ? BoxDecoration(
                                            color: nc.primary,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: nc.primary
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          )
                                        : BoxDecoration(
                                            color: nc.surface,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: nc.divider, width: 0.5),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.18),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                    child: unread > 0
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '$unread 条新消息',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.keyboard_arrow_down,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                            ],
                                          )
                                        : Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 18,
                                            color: nc.textPrimary,
                                          ),
                                  ),
                                ),
                              );
                            }(),
                          ]
                        : []),
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
        final hasNewer = controller.hasNewerMessages;
        final itemCount = controller.messages.length + (hasOlder ? 1 : 0) + (hasNewer ? 1 : 0);
        return ListView.builder(
            controller: scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          itemCount: itemCount,
          cacheExtent: 4000, // 【流畅度·治 B】放大缓存窗口：视口外保留 4000px 气泡，滚回长消息不销毁/不重测 markdown（对齐 Operit 大缓存窗口原则）。原 500px 太小，长消息滚回频繁重建→卡顿。
          // ChatMessage 是 ChangeNotifier，流式更新时仅对应气泡局部重建；
          // 必须逐条用 ListenableBuilder(msg) 包住，否则流式期间 controller 不通知、气泡不刷新
          itemBuilder: (c, i) {
            // 顶部「加载更早消息」
            if (hasOlder && i == 0) {
              return _OlderMessagesHeader(
                onLoad: controller.loadOlderMessages,
              );
            }
            // 底部「加载较新消息」
            final msgIdx = i - (hasOlder ? 1 : 0);
            if (hasNewer && msgIdx == controller.messages.length) {
              return _NewerMessagesFooter(
                onLoad: controller.loadNewerMessages,
              );
            }
            final msg = controller.messages[msgIdx];
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
                )
              )
            );
          },
        ); // close ListView.builder, end return
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

class _NewerMessagesFooter extends StatelessWidget {
  final Future<void> Function() onLoad;
  const _NewerMessagesFooter({required this.onLoad});

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: TextButton.icon(
          onPressed: () => onLoad(),
          icon: Icon(Icons.history, size: 16, color: nc.textSecondary),
          label: Text(
            '加载较新消息',
            style: TextStyle(fontSize: 13, color: nc.textSecondary),
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

