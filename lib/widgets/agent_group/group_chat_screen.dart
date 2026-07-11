import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../core/agent_colors.dart';
import '../../core/design_tokens.dart';
import '../../widgets/common_widgets.dart';
import '../../core/app_router.dart';
import '../state_placeholder.dart';
import '../../widgets/session_info_button.dart';
import 'group_chat_controller.dart';
import 'group_status_bar.dart';
import 'group_message_bubble.dart';
import 'group_chat_input_bar.dart';
import 'group_mention_sheet.dart';

/// 群聊主页
///
/// 现在是「纯视图」：状态与编排逻辑全部下沉到 [GroupChatController]，
/// 本屏只管渲染 + 把用户操作（发送/停止/返回/编辑/加载更早）转交给控制器，
/// 通过 [ListenableBuilder] 监听控制器变化重建。
class GroupChatScreen extends StatefulWidget {
  final String groupId;
  const GroupChatScreen({super.key, required this.groupId});
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  late final GroupChatController _controller = GroupChatController(groupId: widget.groupId);

  // ── 流式贴底节流：下一帧 postFrame jumpTo，去重避免堆积 ──
  bool _pendingScroll = false;

  // ── 滚动状态：上滑后停止自动贴底，避免与阅读打架；程序滚动期间忽略 _onScroll ──
  bool _showScrollBottom = false;
  bool _userScrolledUp = false;
  bool _autoScrolling = false;
  late final AnimationController _scrollAnim;

  // ── 进入群聊：先 invisible 把列表定位到底部再淡入，消除「先显示顶部再猛跳底部」的可见跳变 ──
  bool _ready = false;

  // ── 加载更早消息的 anchor（纯 UI，钉住首条可见消息保持滚动位置） ──
  final GlobalKey _anchorKey = GlobalKey();
  int _anchorMsgIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller.onScroll = _scrollDown;
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
    // 首帧 build 完成后再触发异步加载，避免 _load 的 Future 链与首帧渲染竞争
    // （在低性能设备 / 测试 fake-async 调度下，pumpAndSettle 可能早于加载完成返回，
    //  导致集成测试偶发断言群数据未渲染）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _controller.load();
      if (!mounted) return;
      if (_controller.group == null) {
        Navigator.of(context).pop();
        return;
      }
      // 重新进入群聊：默认滚动到最新消息（贴底），符合聊天惯例。
      // 必须在 load() 触发的重建（ListView 已 attach 到 ScrollController）完成后再跳；
      // 先把列表 invisible 地定位到底部（双阶段校正动态高度），完成后再 _ready 淡入，
      // 避免首帧先渲染顶部旧消息、再猛跳到底部的可见卡顿（见 _jumpToBottomInstant）。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToBottomInstant(() {
          if (mounted) setState(() => _ready = true);
        });
      });
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _scrollAnim.dispose();
    // 解除对滚动控制器的引用：界面关闭后后台流仍在跑，
    // 避免流回调一个已 dispose 的 ScrollController。
    _controller.onScroll = null;
    _controller.dispose();
    super.dispose();
  }

  /// 流式期间实时贴底：下一帧布局完成后 jump 到末尾，消除旧 Timer+animateTo 节流造成的「定期猛跳」。
  /// 用 [_pendingScroll] 去重，避免每个流式 token 都注册一次 postFrame 回调而堆积。
  void _scrollDown() {
    if (_userScrolledUp || _autoScrolling || _pendingScroll || !_ready) return;
    _pendingScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScroll = false;
      if (!_scrollCtrl.hasClients || _userScrolledUp || _autoScrolling) return;
      _autoScrolling = true;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      _autoScrolling = false;
    });
  }

  /// 监听用户滚动：上滑超过阈值即标记“已离开底部”，隐藏自动贴底、显示回到底部按钮。
  void _onScroll() {
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

  /// 进入群聊时的即时贴底：invisible 地把滚动定位到末尾，完成后再由外部淡入显示。
  /// 两阶段校正：首跳让动态 item 高度完成布局、把 maxScrollExtent 推到真实值，
  /// 下一帧再跳一次到真正的最大处（仅跳一次在动态 item 高度下会差一截）。
  /// 首帧即定位在底部、列表尚未可见，因此用户看不到任何跳变。
  void _jumpToBottomInstant(VoidCallback onDone) {
    if (!_scrollCtrl.hasClients) {
      onDone();
      return;
    }
    _userScrolledUp = false;
    _autoScrolling = true;
    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    _autoScrolling = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) {
        onDone();
        return;
      }
      _autoScrolling = true;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      _autoScrolling = false;
      // 第三帧（布局稳定后）再通知显示，确保落点已是真实底部
      WidgetsBinding.instance.addPostFrameCallback((_) => onDone());
    });
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    _inputFocus.unfocus();
    _userScrolledUp = false;
    _controller.send(text);
  }

  Future<void> _editGroup() async {
    final g = _controller.group;
    if (g == null) return;
    final updated = await AppRouter.editGroup(context, existing: g);
    if (updated == null) return;
    await _controller.applyGroupUpdate(updated);
  }

  /// 加载更早的消息：向前提一页，并用 anchor 钉住当前首条可见消息，
  /// 通过两帧测量其位置变化，jump 补偿，避免阅读位置跳动。
  void _loadEarlier() {
    if (_controller.windowStart <= 0 || _controller.busy) return;
    // 先把 anchor 钉在当前首条可见消息上并重建，使其 attach 到渲染树
    setState(() => _anchorMsgIndex = _controller.windowStart);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final obj = _anchorKey.currentContext?.findRenderObject();
      final vp = obj == null ? null : RenderAbstractViewport.of(obj);
      if (obj == null || vp == null || !_scrollCtrl.hasClients) return;
      final r1 = vp.getOffsetToReveal(obj, 0.0).offset;
      _controller.loadEarlierPage();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final obj2 = _anchorKey.currentContext?.findRenderObject();
        final vp2 = obj2 == null ? null : RenderAbstractViewport.of(obj2);
        if (obj2 != null && vp2 != null && _scrollCtrl.hasClients) {
          final r2 = vp2.getOffsetToReveal(obj2, 0.0).offset;
          _scrollCtrl.jumpTo(_scrollCtrl.offset + (r2 - r1));
        }
        if (mounted) setState(() => _anchorMsgIndex = -1);
      });
    });
  }

  Widget _buildLoadEarlier() {
    final remaining = _controller.windowStart;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpaceToken.sm),
      child: Center(
        child: TextButton(
          onPressed: _loadEarlier,
          child: Text(
            remaining > 0 ? '查看更早的消息（$remaining 条）' : '查看更早的消息',
            style: TextStyle(
              fontSize: 13,
              color: AgentColors.of(context).textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  void _stop() {
    _controller.stop();
  }

  /// 流式过程中拦截返回：先停止流并存盘，再退出
  /// 流式/讨论过程中返回：不中断模型，让它后台继续跑完，由控制器的 finally 存盘。
  Future<void> _handleBack() async {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    // 整个依赖状态的子树都监听控制器，状态变更（消息/忙碌/分页/接力）自动重建。
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.group == null) {
          return Scaffold(body: StatePlaceholder.loading());
        }

        return PopScope(
          // 允许随时返回：讨论在后台继续跑，结束后由控制器的 finally 存盘
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBack();
          },
          child: Scaffold(
            backgroundColor: nc.background,
            appBar: AppTopBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                color: nc.textPrimary,
                onPressed: _handleBack,
              ),
              title: _controller.group!.name,
              actions: [
                SessionInfoButton(
                  getTokens: () => _controller.estimatedContextTokens,
                  getWindowSize: () => _controller.contextWindowSize,
                  getThreshold: () => _controller.contextCompressionThreshold,
                  listenable: _controller,
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: nc.textPrimary),
                  onPressed: _editGroup,
                ),
              ],
            ),
            body: Column(
              children: [
                // ── Agent 状态栏 ──
                if (_controller.busy || _controller.participatedAgents.isNotEmpty)
                  RepaintBoundary(
                    child: GroupStatusBar(
                      members: _controller.members,
                      agentStatus: _controller.agentStatus,
                      discussionRound: _controller.discussionRound,
                      participatedAgents: _controller.participatedAgents,
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      // 进入群聊时列表先在 opacity:0 下完成贴底（见 _jumpToBottomInstant），
                      // 完成后 _ready 置 true 才淡入显示，首帧即见底部、无可见跳变；
                      // Opacity 不改变 onstage 状态，子项照常布局/测量，仅不绘制，降低进入首帧视觉开销。
                      Opacity(
                        opacity: _ready ? 1.0 : 0.0,
                        child: _controller.messages.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Text(
                                    '直接发消息，系统会自动调度 Agent 回复\n也可以 @名字 指定 Agent 参与讨论',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: nc.textSecondary),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollCtrl,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SpaceToken.md,
                                  vertical: SpaceToken.md,
                                ),
                                cacheExtent: 1000, // 缓存窗口：视口外多保留 1000px 的气泡，滚回长消息不重建/重测
                                itemCount: _controller.messages.length -
                                    _controller.windowStart +
                                    (_controller.windowStart > 0 ? 1 : 0),
                                itemBuilder: (c, i) {
                            // 列表首项为"加载更早消息"入口（仅当窗口未到开头）
                            if (_controller.windowStart > 0 && i == 0) {
                              return _buildLoadEarlier();
                            }
                            final msgIndex = _controller.windowStart +
                                (i - (_controller.windowStart > 0 ? 1 : 0));
                            final m = _controller.messages[msgIndex];
                            // 每条消息独立监听自身 ChatMessage(ChangeNotifier)，
                            // 流式期间仅正在生成的那个气泡局部重建，不再整屏 setState。
                            // 钉住首条可见消息，加载更早时保持滚动位置不跳动。
                            // 外层 RepaintBoundary：长讨论滚动时只重绘进出视口的气泡，
                            // 静止气泡不参与重绘，消除整列表滚动的连带重绘卡顿。
                            return RepaintBoundary(
                              child: ListenableBuilder(
                                key: msgIndex == _anchorMsgIndex ? _anchorKey : null,
                                listenable: m,
                                builder: (_, __) => GroupMessageBubble(
                                  msg: m,
                                  speaker: m.isUser ? null : _controller.byId[m.speakerId ?? ''],
                                  nc: nc,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 12,
                        child: AnimatedOpacity(
                          opacity: _showScrollBottom ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
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
                GroupChatInputBar(
                  controller: _inputCtrl,
                  focusNode: _inputFocus,
                  busy: _controller.busy,
                  isCompressing: _controller.isCompressing,
                  members: _controller.members,
                  bottomSafe: MediaQuery.of(context).padding.bottom,
                  onSend: _send,
                  onStop: _stop,
                  onMention: () => showGroupMentionSheet(
                    context,
                    members: _controller.members,
                    controller: _inputCtrl,
                    focusNode: _inputFocus,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
