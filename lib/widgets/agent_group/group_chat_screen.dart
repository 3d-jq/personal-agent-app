import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import '../../core/agent_colors.dart';
import '../../core/app_router.dart';
import '../../core/app_config.dart';
import '../../models/agent.dart';
import '../../models/agent_group.dart';
import '../../models/chat_message.dart';
import '../../services/agent_group_storage.dart';
import '../../services/agent_runner.dart';
import '../../services/agent_storage.dart';
import '../../services/ai_service.dart';
import '../../services/chat_stream_event.dart';
import '../../services/typewriter_buffer.dart';
import '../../core/service_locator.dart';
import '../../services/connectivity_service.dart';
import '../../tools/tools.dart';
import '../../widgets/ai_settings_sheet.dart';
import '../chat_bubble.dart';
import '../state_placeholder.dart';
import '../../screens/chat_helpers.dart';
import 'agent_group_theme.dart';
import 'group_chat_coordinator.dart';
import 'group_status_bar.dart';

/// 群聊主页
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
  final AISettings _aiSettings = getIt<AISettings>();
  late final ToolRegistry _baseRegistry = () {
    final r = ToolRegistry();
    if (r.all.isEmpty) registerAllTools(r);
    return r;
  }();
  late final AgentRunner _runner = AgentRunner(baseRegistry: _baseRegistry);
  late GroupChatCoordinator _coordinator;

  AgentGroup? _group;
  List<ChatMessage> _messages = [];
  List<Agent> _members = [];
  Map<String, Agent> _byId = {};
  Map<String, Agent> _byName = {};
  bool _busy = false;
  bool _stopped = false;

  // ── Agent 状态跟踪 ──
  Map<String, AgentStatus> _agentStatus = {};
  int _discussionRound = 0;
  Set<String> _participatedAgents = {};

  // ── Stop 完整取消：管理所有活跃流 ──
  final List<StreamSubscription<ChatStreamEvent>> _activeSubs = [];

  // ── 滚动节流 ──
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    _scrollTimer?.cancel();
    for (final sub in _activeSubs) {
      sub.cancel();
    }
    _activeSubs.clear();
    super.dispose();
  }

  Future<void> _load() async {
    await _aiSettings.load();
    final g = (await getIt<AgentGroupStorage>().loadAll())
        .where((x) => x.id == widget.groupId)
        .firstOrNull;
    if (g == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final allAgents = await getIt<AgentStorage>().loadAll();
    final ms = g.agentIds
        .map((id) => allAgents.where((a) => a.id == id).firstOrNull)
        .whereType<Agent>()
        .toList();
    
    // 自动清理：移除不存在的 Agent
    final validIds = ms.map((a) => a.id).toSet();
    final invalidIds = g.agentIds.where((id) => !validIds.contains(id)).toList();
    if (invalidIds.isNotEmpty) {
      g.agentIds.removeWhere((id) => !validIds.contains(id));
      await getIt<AgentGroupStorage>().save(g);
    }
    
    if (!mounted) return;
    setState(() {
      _group = g;
      _messages = List.from(g.messages);
      _members = ms;
      _byId = {for (final a in ms) a.id: a};
      _byName = {for (final a in ms) a.name: a};
      _coordinator = GroupChatCoordinator(
        aiSettings: _aiSettings,
        members: ms,
      );
    });
  }

  Future<void> _saveGroup() async {
    final g = _group;
    if (g == null) return;
    g.messages = List.from(_messages);
    await getIt<AgentGroupStorage>().save(g);
  }

  Future<void> _editGroup() async {
    final g = _group;
    if (g == null) return;
    final oldMemberIds = Set<String>.from(g.agentIds);
    final updated = await AppRouter.editGroup(context, existing: g);
    if (updated == null) return;
    final newMemberIds = Set<String>.from(updated.agentIds);
    
    // 检测成员变更，添加系统消息通知
    final addedIds = newMemberIds.difference(oldMemberIds);
    final removedIds = oldMemberIds.difference(newMemberIds);
    
    final allAgents = await getIt<AgentStorage>().loadAll();
    for (final id in addedIds) {
      final agent = allAgents.where((a) => a.id == id).firstOrNull;
      if (agent != null) {
        _messages.add(ChatMessage(
          text: '${agent.name} 加入了群聊',
          isUser: false,
          speakerId: 'system',
        ));
      }
    }
    for (final id in removedIds) {
      final agent = allAgents.where((a) => a.id == id).firstOrNull;
      if (agent != null) {
        _messages.add(ChatMessage(
          text: '${agent.name} 离开了群聊',
          isUser: false,
          speakerId: 'system',
        ));
      }
    }
    
    updated.messages = List.from(_messages);
    await getIt<AgentGroupStorage>().save(updated);
    await _load();
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

  Future<void> _send() async {
    if (_group == null || _busy) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    final mentionNames = parseMentions(text, _members);
    final mentionAgents = mentionNames
        .map((n) => _byName[n])
        .whereType<Agent>()
        .toList();

    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, mentions: mentionNames),
      );
      _inputCtrl.clear();
      _inputFocus.unfocus();
    });

    _scrollDown();

    // 是否直接 @ 了某个 Agent
    final hasDirectMentions = mentionAgents.isNotEmpty;

    if (!await getIt<ConnectivityService>().check()) {
      setState(() {
        _messages.add(ChatMessage(text: '当前无网络连接，请检查网络后重试', isUser: false));
      });
      await _saveGroup();
      _scrollDown();
      return;
    }

    if (!_aiSettings.hasVendor) {
      setState(() {
        _messages.add(ChatMessage(text: '请先在侧边栏设置中配置 AI 后端', isUser: false));
      });
      await _saveGroup();
      _scrollDown();
      return;
    }

    // ── 混合协作引擎 ──
    setState(() {
      _busy = true;
      _discussionRound = 0;
      _participatedAgents.clear();
      // 初始化所有 Agent 状态为 idle
      _agentStatus = {for (final m in _members) m.id: AgentStatus.idle};
    });
    _stopped = false;
    try {
      final handled = <String>{};
      const maxRounds = 5;

      if (hasDirectMentions) {
        // 有 @ 点名 → 先让被点的 Agent 回复
        for (final a in mentionAgents) {
          if (_stopped) break;
          handled.add(a.id);
          _discussionRound++;
          _participatedAgents.add(a.id);
          setState(() => _agentStatus[a.id] = AgentStatus.thinking);
          await _runOneAndAppend(a);
          setState(() => _agentStatus[a.id] = AgentStatus.replied);
        }
        // 然后检查 Agent 回复中是否有 @ 其他 Agent，触发接力
        await _handleRelay(handled, maxRounds);
      } else {
        // 没 @ 点名 → 自动调度：系统判断谁该回复
        final speakerName = await _autoPickSpeaker();
        if (speakerName != null && speakerName != 'STOP') {
          final firstAgent = _byName[speakerName];
          if (firstAgent != null) {
            handled.add(firstAgent.id);
            _discussionRound++;
            _participatedAgents.add(firstAgent.id);
            setState(() => _agentStatus[firstAgent.id] = AgentStatus.thinking);
            await _runOneAndAppend(firstAgent);
            setState(() => _agentStatus[firstAgent.id] = AgentStatus.replied);
            // 检查是否触发接力
            await _handleRelay(handled, maxRounds);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      await _saveGroup();
    }
  }

  /// 处理 Agent 接力：检查最新回复中是否有 @ 其他 Agent
  Future<void> _handleRelay(Set<String> handled, int maxRounds) async {
    for (var round = 0; round < maxRounds && !_stopped; round++) {
      // 获取最新的 Agent 回复
      final lastAgentMsg = _messages.lastWhere(
        (m) => !m.isUser && m.speakerId != null,
        orElse: () => ChatMessage(text: '', isUser: false),
      );
      
      if (lastAgentMsg.text.isEmpty) break;
      
      // 解析回复中的 @ 提及
      final relayMentions = parseMentions(lastAgentMsg.text, _members);
      final relayAgents = relayMentions
          .map((n) => _byName[n])
          .whereType<Agent>()
          .where((a) => !handled.contains(a.id))
          .toList();
      
      if (relayAgents.isEmpty) break;
      
      // 让被 @ 的 Agent 回复
      for (final a in relayAgents) {
        if (_stopped) break;
        handled.add(a.id);
        _discussionRound++;
        _participatedAgents.add(a.id);
        setState(() => _agentStatus[a.id] = AgentStatus.thinking);
        await _runOneAndAppend(a);
        setState(() => _agentStatus[a.id] = AgentStatus.replied);
      }
    }
  }

  /// 自动调度：系统判断哪个 Agent 应该回复
  Future<String?> _autoPickSpeaker() {
    return _coordinator.autoPickSpeaker(
      group: _group,
      messages: _messages,
    );
  }

  /// 执行一个 Agent（_runOneAgent 已负责消息的创建与渲染）
  Future<void> _runOneAndAppend(Agent agent) async {
    await _runOneAgent(agent);
  }

  /// 批量执行 Agent（串行，每个等完成后再下一个），返回回复文本列表
  Future<List<String>> _runBatch(List<Agent> agents) async {
    final results = <String>[];
    for (final agent in agents) {
      if (_stopped) break;
      results.add(await _runOneAgent(agent));
    }
    return results;
  }

  /// 执行一个 Agent 并返回它的回复文本
  Future<String> _runOneAgent(Agent agent) async {
    VendorConfig? vendor;
    if (agent.vendorId.isNotEmpty) {
      vendor = _aiSettings.vendors
          .where((v) => v.id == agent.vendorId)
          .firstOrNull;
    }
    vendor ??=
        _aiSettings.selectedVendor ??
        (_aiSettings.vendors.isNotEmpty ? _aiSettings.vendors.first : null);
    if (vendor == null || vendor.apiKey.isEmpty) {
      final errText = '${agent.name} 没有可用的 AI 后端';
      setState(() {
        _messages.add(
          ChatMessage(text: errText, isUser: false, speakerId: agent.id),
        );
      });
      _scrollDown();
      return errText;
    }

    final placeholder = ChatMessage(
      text: '',
      isUser: false,
      speakerId: agent.id,
      isStreaming: true,
    );
    setState(() => _messages.add(placeholder));
    _scrollDown();

    final buf = StringBuffer();
    final typewriter = TypewriterBuffer(charsPerTick: 4);
    Timer? typewriterTimer;
    List<TimelineStep>? currentSteps;
    final toolInteractions = <Map<String, dynamic>>[];
    StreamSubscription<ChatStreamEvent>? sub;
    try {
      final history = _messages.where((m) => m != placeholder).toList();
      final stream = _runner.run(
        agent: agent,
        vendor: vendor!,
        groupMessages: history,
        memberNames: _members.map((a) => a.name).toList(),
        speakerNames: {for (final a in _members) a.id: a.name},
        memberRoles: {for (final a in _members) a.name: a.role},
        groupName: _group?.name ?? '',
        groupDesc: _group?.description ?? '',
        thinkingEffort: _aiSettings.thinkingEffort,
      );
      final completer = Completer<void>();
      sub = stream.listen(
        (event) {
          switch (event) {
            case ThinkingChunkEvent(:final text):
              break;
            case TextChunkEvent(:final text):
              buf.write(text);
              typewriter.append(text);
              break;
            case ToolStartEvent(:final name, :final concurrentCount, :final arguments):
              currentSteps ??= [];
              for (final s in currentSteps!) {
                if (s.type == TimelineStepType.thinking &&
                    s.status == TimelineStepStatus.running) {
                  s.status = TimelineStepStatus.done;
                }
              }
              final detailLabel = toolLabel(name, arguments: arguments, detailed: true);
              final suffix = concurrentCount > 1 ? ' ×$concurrentCount' : '';
              currentSteps!.add(
                TimelineStep(
                  label: '$detailLabel$suffix',
                  type: TimelineStepType.tool,
                  status: TimelineStepStatus.running,
                  detail: '工具: $name',
                ),
              );
              break;
            case ToolDoneEvent(:final name):
              if (currentSteps != null) {
                final idx = currentSteps!.lastIndexWhere(
                  (s) =>
                      s.type == TimelineStepType.tool &&
                      s.detail == '工具: $name' &&
                      s.status == TimelineStepStatus.running,
                );
                if (idx >= 0) {
                  currentSteps![idx].status = TimelineStepStatus.done;
                  currentSteps![idx].detail = '执行成功';
                }
              }
              break;
            case ToolErrorEvent(:final name, :final message):
              if (currentSteps != null) {
                final idx = currentSteps!.lastIndexWhere(
                  (s) =>
                      s.type == TimelineStepType.tool &&
                      s.detail == '工具: $name' &&
                      s.status == TimelineStepStatus.running,
                );
                if (idx >= 0) {
                  currentSteps![idx].status = TimelineStepStatus.error;
                  currentSteps![idx].detail = message;
                }
              }
              break;
            case ToolMediaEvent(:final url):
              buf.write('\n$url\n');
              typewriter.append('\n$url\n');
              break;
            case ToolInteractionEvent(:final toolCalls, :final toolResults):
              toolInteractions.add({
                'toolCalls': toolCalls,
                'toolResults': toolResults,
              });
              break;
            case TaskPlanEvent():
              break;
            case ErrorEvent(:final message):
              buf.write('\n\n[错误: $message]');
              typewriter.append('\n\n[错误: $message]');
              break;
          }
          placeholder.text = typewriter.visibleText;
          placeholder.steps = currentSteps;
          if (mounted) setState(() {});
          _scrollDown();

          // 启动打字机定时器
          if (typewriterTimer == null) {
            typewriterTimer = Timer.periodic(const Duration(milliseconds: 24), (_) {
              if (!typewriter.hasPending) {
                typewriterTimer?.cancel();
                typewriterTimer = null;
                return;
              }
              typewriter.revealNext();
              placeholder.text = typewriter.visibleText;
              if (mounted) setState(() {});
              _scrollDown();
            });
          }
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
          buf.write('\n\n[错误: $e]');
          typewriter.append('\n\n[错误: $e]');
          typewriter.revealAll();
          placeholder.text = typewriter.visibleText;
          completer.complete();
        },
        cancelOnError: true,
      );
      _activeSubs.add(sub!);
      await completer.future;
    } finally {
      await sub?.cancel();
      typewriterTimer?.cancel();
      if (sub != null) _activeSubs.remove(sub);
      placeholder.isStreaming = false;
      final steps = currentSteps;
      if (steps != null && steps.isNotEmpty) {
        finishRunningSteps(steps);
        if (steps.last.type == TimelineStepType.thinking) {
          steps.last.label = '任务完成';
        }
        placeholder.steps = steps;
      }
      if (toolInteractions.isNotEmpty) {
        placeholder.toolInteractions = toolInteractions;
      }
    }
    if (mounted) setState(() {});
    _scrollDown();
    return buf.toString();
  }

  void _showMentionSheet(AgentColors nc) {
    if (_members.isEmpty) return;
    final insertAt = (String name) {
      final cur = _inputCtrl.text;
      final sel = _inputCtrl.selection;
      final pos = sel.start.clamp(0, cur.length);
      final insert = '@$name ';
      _inputCtrl.value = TextEditingValue(
        text: cur.replaceRange(pos, pos, insert),
        selection: TextSelection.collapsed(offset: pos + insert.length),
      );
      setState(() {});
      _inputFocus.requestFocus();
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: nc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (context, scrollCtrl) => SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: nc.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '选择要 @ 的 Agent',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: nc.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final a = _members[index];
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: nc.primarySurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: nc.divider, width: 0.5),
                        ),
                        child: Text(
                          a.avatar.isNotEmpty ? a.avatar : a.name.characters.first,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: nc.textPrimary,
                          ),
                        ),
                      ),
                      title: Text(
                        a.name,
                        style: TextStyle(fontSize: 15, color: nc.textPrimary),
                      ),
                      subtitle: a.role.isNotEmpty
                          ? Text(
                              a.role,
                              style: TextStyle(fontSize: 12, color: nc.textSecondary),
                            )
                          : null,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        insertAt(a.name);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _stop() {
    _stopped = true;
    for (final s in _activeSubs.toList()) {
      s.cancel();
    }
    _activeSubs.clear();
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    if (_group == null) {
      return Scaffold(body: StatePlaceholder.loading());
    }

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIconsRegular.arrowLeft, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _group!.name,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: nc.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(PhosphorIconsRegular.pencilSimple, color: nc.textPrimary),
            onPressed: _editGroup,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Agent 状态栏 ──
          if (_busy || _participatedAgents.isNotEmpty)
            GroupStatusBar(
              members: _members,
              agentStatus: _agentStatus,
              discussionRound: _discussionRound,
              participatedAgents: _participatedAgents,
            ),
          Expanded(
            child: _messages.isEmpty
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
                      horizontal: 12,
                      vertical: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (c, i) {
                      final m = _messages[i];
                      return _GroupBubble(
                        msg: m,
                        speaker: m.isUser ? null : _byId[m.speakerId ?? ''],
                        nc: nc,
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: nc.primarySurface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              inputDecorationTheme: const InputDecorationTheme(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                              ),
                            ),
                            child: TextField(
                              controller: _inputCtrl,
                              focusNode: _inputFocus,
                              minLines: 1,
                              maxLines: 6,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: TextStyle(
                                fontSize: 15,
                                color: nc.textPrimary,
                                height: 1.5,
                              ),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: _members.isEmpty
                                    ? '先把 Agent 拉进群再说'
                                    : '说点什么，@名字 来召唤 Agent',
                                hintStyle: TextStyle(
                                  color: nc.textSecondary.withValues(alpha: 0.6),
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Row(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _showMentionSheet(nc);
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: nc.surface,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '@',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _members.isNotEmpty
                                          ? nc.textPrimary
                                          : nc.textDisabled,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (_busy) {
                                    _stop();
                                  } else if (_inputCtrl.text.trim().isNotEmpty) {
                                    _send();
                                  }
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _busy
                                        ? nc.error.withValues(alpha: 0.1)
                                        : _inputCtrl.text.trim().isEmpty
                                        ? nc.surface
                                        : nc.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    _busy
                                        ? PhosphorIconsRegular.stop
                                        : PhosphorIconsRegular.arrowUp,
                                    size: 18,
                                    color: _busy
                                        ? nc.error
                                        : _inputCtrl.text.trim().isEmpty
                                        ? nc.textSecondary
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 2),
                  child: Text(
                    '直接发消息，系统会自动调度 Agent',
                    style: TextStyle(
                      fontSize: 11,
                      color: nc.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 群聊气泡
class _GroupBubble extends StatelessWidget {
  final ChatMessage msg;
  final Agent? speaker;
  final AgentColors nc;
  const _GroupBubble({
    super.key,
    required this.msg,
    required this.speaker,
    required this.nc,
  });
  @override
  Widget build(BuildContext context) {
    // 系统消息（加入/离开通知）
    if (msg.speakerId == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: nc.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                fontSize: 12,
                color: nc.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    final showHeader = speaker != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: msg.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: nc.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: nc.divider, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: nc.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: nc.divider, width: 0.5),
                      ),
                      child: Text(
                        speaker!.avatar.isNotEmpty
                            ? speaker!.avatar
                            : speaker!.name.characters.first,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      speaker!.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: nc.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ChatBubble(msg: msg, nc: nc),
        ],
      ),
    );
  }
}
