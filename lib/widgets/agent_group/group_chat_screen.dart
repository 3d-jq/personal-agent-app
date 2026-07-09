import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../core/agent_colors.dart';
import '../../core/design_tokens.dart';
import '../../widgets/common_widgets.dart';
import '../../core/app_router.dart';
import '../state_placeholder.dart';
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

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  late final GroupChatController _controller = GroupChatController(groupId: widget.groupId);

  // ── 滚动节流 ──
  Timer? _scrollTimer;

  // ── 加载更早消息的 anchor（纯 UI，钉住首条可见消息保持滚动位置） ──
  final GlobalKey _anchorKey = GlobalKey();
  int _anchorMsgIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller.onScroll = _scrollDown;
    // 首帧 build 完成后再触发异步加载，避免 _load 的 Future 链与首帧渲染竞争
    // （在低性能设备 / 测试 fake-async 调度下，pumpAndSettle 可能早于加载完成返回，
    //  导致集成测试偶发断言群数据未渲染）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _controller.load();
      if (mounted && _controller.group == null) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    _scrollTimer?.cancel();
    // 解除对滚动控制器的引用：界面关闭后后台流仍在跑，
    // 避免流回调一个已 dispose 的 ScrollController。
    _controller.onScroll = null;
    _controller.dispose();
    super.dispose();
  }

  /// 滚动节流：最多每 80ms 滚一次
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

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    _inputFocus.unfocus();
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpaceToken.md,
                            vertical: SpaceToken.md,
                          ),
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
                            return ListenableBuilder(
                              key: msgIndex == _anchorMsgIndex ? _anchorKey : null,
                              listenable: m,
                              builder: (_, __) => GroupMessageBubble(
                                msg: m,
                                speaker: m.isUser ? null : _controller.byId[m.speakerId ?? ''],
                                nc: nc,
                              ),
                            );
                          },
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
