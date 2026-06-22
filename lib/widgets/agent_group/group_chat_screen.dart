import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/agent_colors.dart';
import '../../core/app_animations.dart';
import '../../models/agent.dart';
import '../../models/agent_group.dart';
import '../../models/chat_message.dart';
import '../../services/agent_group_storage.dart';
import '../../services/agent_runner.dart';
import '../../services/agent_storage.dart';
import '../../services/ai_service.dart';
import '../../services/chat_stream_event.dart';
import '../../services/connectivity_service.dart';
import '../../tools/tools.dart';
import '../../widgets/ai_settings_sheet.dart';
import '../chat_bubble.dart';
import '../../screens/chat_helpers.dart';
import 'agent_group_theme.dart';
import 'group_edit_page.dart';

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
  final AISettings _aiSettings = AISettings();
  late final ToolRegistry _baseRegistry = () {
    final r = ToolRegistry();
    if (r.all.isEmpty) registerAllTools(r);
    return r;
  }();
  late final AgentRunner _runner = AgentRunner(baseRegistry: _baseRegistry);

  AgentGroup? _group;
  List<ChatMessage> _messages = [];
  List<Agent> _members = [];
  Map<String, Agent> _byId = {};
  Map<String, Agent> _byName = {};
  Agent? _coordinator; // 群的协调者 Agent
  bool _busy = false;
  bool _stopped = false;

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
    final g = (await AgentGroupStorage().loadAll())
        .where((x) => x.id == widget.groupId)
        .firstOrNull;
    if (g == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final allAgents = await AgentStorage().loadAll();
    final ms = g.agentIds
        .map((id) => allAgents.where((a) => a.id == id).firstOrNull)
        .whereType<Agent>()
        .toList();
    if (!mounted) return;
    setState(() {
      _group = g;
      _messages = List.from(g.messages);
      _members = ms;
      _byId = {for (final a in ms) a.id: a};
      _byName = {for (final a in ms) a.name: a};
      _coordinator = ms.where((a) => a.isCoordinator).firstOrNull;
    });
  }

  Future<void> _saveGroup() async {
    final g = _group;
    if (g == null) return;
    g.messages = List.from(_messages);
    await AgentGroupStorage().save(g);
  }

  Future<void> _editGroup() async {
    final g = _group;
    if (g == null) return;
    final result = await Navigator.of(context).push<(AgentGroup, List<String>, List<String>)>(
      SlideFadeRoute(
        page: GroupEditPage(existing: g),
      ),
    );
    if (result == null) return;
    final (updated, addedNames, removedNames) = result;
    final sysMsgs = <String>[];
    for (final name in addedNames) {
      sysMsgs.add('🔔 $name 加入了群聊');
    }
    for (final name in removedNames) {
      sysMsgs.add('🔔 $name 离开了群聊');
    }
    if (sysMsgs.isNotEmpty) {
      setState(() {
        for (final msg in sysMsgs) {
          _messages.add(ChatMessage(text: msg, isUser: false));
        }
      });
    }
    updated.messages = List.from(_messages);
    await AgentGroupStorage().save(updated);
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
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        mentions: mentionNames,
      ));
      _inputCtrl.clear();
      _inputFocus.unfocus();
    });

    _scrollDown();

    // 是否直接 @ 了某个 Agent
    final hasDirectMentions = mentionAgents.isNotEmpty;

    if (!await ConnectivityService().check()) {
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

    // ── 协作引擎（Manager 模式）──
    setState(() => _busy = true);
    _stopped = false;
    try {
      final handled = <String>{};
      const maxRounds = 3;

      if (hasDirectMentions) {
        // 有 @ 点名 → 直接让被点的 Agent 回复（不接力）
        for (final a in mentionAgents) {
          if (_stopped) break;
          handled.add(a.id);
          await _runOneAndAppend(a);
        }
      } else {
        // 没 @ 点名 → Manager 选人
        final managerAgent = _coordinator ?? mentionAgents.firstOrNull;
        if (managerAgent == null) return;

        final mentionNames = <String>[];
        for (var round = 0; round < maxRounds && !_stopped; round++) {
          // Manager 判断谁该发言
          final nextName = await _managerPickSpeaker(managerAgent, mentionNames);
          if (nextName == null || nextName == 'STOP') break;

          final nextAgent = _byName[nextName];
          if (nextAgent == null || handled.contains(nextAgent.id)) continue;
          handled.add(nextAgent.id);
          mentionNames.add(nextName);

          await _runOneAndAppend(nextAgent);
        }
      }
    } finally {
      setState(() => _busy = false);
      await _saveGroup();
    }
  }

  /// 执行一个 Agent（_runOneAgent 已负责消息的创建与渲染）
  Future<void> _runOneAndAppend(Agent agent) async {
    await _runOneAgent(agent);
  }

  /// Manager 判断下一位发言的 Agent 名字，返回 null / 'STOP' 表示无需再发言。
  ///
  /// 用一个轻量 LLM 调用，根据用户消息 + 已有对话 + 各 Agent 的角色描述，
  /// 选出最适合接下来回复的 Agent。
  Future<String?> _managerPickSpeaker(Agent manager, List<String> alreadySpoken) async {
    final vendor = _aiSettings.selectedVendor ??
        (_aiSettings.vendors.isNotEmpty ? _aiSettings.vendors.first : null);
    if (vendor == null || vendor.apiKey.isEmpty) return null;

    // 排除已发言和 Manager 自己
    final candidates = _members
        .where((a) => a.id != manager.id && !alreadySpoken.contains(a.name))
        .toList();
    if (candidates.isEmpty) return 'STOP';

    final roleList = candidates
        .map((a) => '- ${a.name}：${a.role.isNotEmpty ? a.role : '通用助手'}')
        .join('\n');

    final prompt = '''你是「${manager.name}」，群的协调者。
根据用户的消息和已有对话，判断哪位成员最适合回复。
只能从下面列表中选择一人，或回复 STOP 表示不需要更多回复。

【可选成员】
$roleList

【已有回复的成员】
${alreadySpoken.isEmpty ? '(暂无)' : alreadySpoken.join('、')}

【用户的消息 + 对话】
${_messages.map((m) => '${m.isUser ? "群主" : m.speakerId ?? '?'}: ${m.text}').join('\n')}

请只回复一个名字或 STOP：''';

    try {
      final ai = AIService(
        baseUrl: vendor.baseUrl,
        apiKey: vendor.apiKey,
        providerName: vendor.name,
        model: vendor.model,
        maxTokens: 50,
      );
      final buf = StringBuffer();
      await for (final event in ai.sendMessageStream([
        {'role': 'user', 'content': prompt},
      ])) {
        if (event is TextChunkEvent) buf.write(event.text);
      }
      final choice = buf.toString().trim();
      // 匹配候选名字
      for (final c in candidates) {
        if (choice.contains(c.name)) return c.name;
      }
      if (choice.toUpperCase().contains('STOP')) return 'STOP';
      return null;
    } catch (_) {
      return null;
    }
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
      vendor = _aiSettings.vendors.where((v) => v.id == agent.vendorId).firstOrNull;
    }
    vendor ??= _aiSettings.selectedVendor ??
        (_aiSettings.vendors.isNotEmpty ? _aiSettings.vendors.first : null);
    if (vendor == null || vendor.apiKey.isEmpty) {
      final errText = '${agent.name} 没有可用的 AI 后端';
      setState(() {
        _messages.add(ChatMessage(text: errText, isUser: false, speakerId: agent.id));
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
    List<TimelineStep>? currentSteps;
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
              // 大模型内部推理，群聊中暂不展示细节
              break;
            case TextChunkEvent(:final text):
              buf.write(text);
              break;
            case ToolStartEvent(:final name, :final concurrentCount):
              currentSteps ??= [];
              // 只结束思考步骤，不影响正在并行执行的工具步骤
              for (final s in currentSteps!) {
                if (s.type == TimelineStepType.thinking && s.status == TimelineStepStatus.running) {
                  s.status = TimelineStepStatus.done;
                }
              }
              final suffix = concurrentCount > 1 ? ' ×$concurrentCount' : '';
              currentSteps!.add(TimelineStep(
                  label: '${toolLabel(name)}$suffix',
                  type: TimelineStepType.tool,
                  status: TimelineStepStatus.running,
                  detail: '工具: $name'));
              break;
            case ToolDoneEvent(:final name):
              if (currentSteps != null) {
                final idx = currentSteps!.lastIndexWhere((s) => s.type == TimelineStepType.tool && s.detail == '工具: $name' && s.status == TimelineStepStatus.running);
                if (idx >= 0) {
                  currentSteps![idx].status = TimelineStepStatus.done;
                  currentSteps![idx].detail = '执行成功';
                }
              }
              break;
            case ToolErrorEvent(:final name, :final message):
              if (currentSteps != null) {
                final idx = currentSteps!.lastIndexWhere((s) => s.type == TimelineStepType.tool && s.detail == '工具: $name' && s.status == TimelineStepStatus.running);
                if (idx >= 0) {
                  currentSteps![idx].status = TimelineStepStatus.error;
                  currentSteps![idx].detail = message;
                }
              }
              break;
            case ToolMediaEvent(:final url):
              buf.write('\n$url\n');
              break;
            case TaskPlanEvent(:final planText):
              buf.write('\n::TASK_PLAN::\n$planText\n::END_TASK_PLAN::\n');
              break;
            case ErrorEvent(:final message):
              buf.write('\n\n[错误: $message]');
              break;
          }
          placeholder.text = buf.toString();
          placeholder.steps = currentSteps;
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
      _activeSubs.add(sub!);
      await completer.future;
    } finally {
      await sub?.cancel();
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
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(color: nc.divider, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('选择要 @ 的 Agent',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: nc.textPrimary)),
            ),
            ..._members.map((a) => ListTile(
                  leading: Container(
                    width: 36, height: 36, alignment: Alignment.center,
                    decoration: BoxDecoration(color: nc.primarySurface, borderRadius: BorderRadius.circular(18)),
                    child: Text(a.avatar.isNotEmpty ? a.avatar : a.name.characters.first,
                        style: const TextStyle(fontSize: 16)),
                  ),
                  title: Text(a.name, style: TextStyle(fontSize: 15, color: nc.textPrimary)),
                  subtitle: a.role.isNotEmpty
                      ? Text(a.role, style: TextStyle(fontSize: 12, color: nc.textSecondary))
                      : null,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    insertAt(a.name);
                  },
                )),
          ],
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_group!.name,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: nc.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: nc.textPrimary),
            onPressed: _editGroup,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        '试着 @ 一个 Agent 开启讨论\n例如：@产品经理 我们该不该做这个功能？',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: nc.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: nc.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: nc.divider, width: 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: TextField(
                        controller: _inputCtrl,
                        focusNode: _inputFocus,
                        minLines: 1, maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: TextStyle(fontSize: 15, color: nc.textPrimary, height: 1.5),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: _members.isEmpty ? '先把 Agent 拉进群再说' : '说点什么，@名字 来召唤 Agent',
                          hintStyle: TextStyle(color: nc.textSecondary.withValues(alpha: 0.6), fontSize: 15, height: 1.5),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
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
                              width: 40, height: 40, alignment: Alignment.center,
                              decoration: BoxDecoration(color: nc.primarySurface, shape: BoxShape.circle),
                              child: Text('@',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600,
                                      color: _members.isNotEmpty ? nc.textPrimary : nc.textDisabled)),
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
                              width: 40, height: 40, alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _busy
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : _inputCtrl.text.trim().isEmpty
                                        ? nc.primarySurface : nc.textPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                                size: 18,
                                color: _busy
                                    ? Colors.red
                                    : _inputCtrl.text.trim().isEmpty ? nc.textSecondary : nc.surface,
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
  const _GroupBubble({super.key, required this.msg, required this.speaker, required this.nc});
  @override
  Widget build(BuildContext context) {
    final showHeader = speaker != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: nc.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24, height: 24, alignment: Alignment.center,
                      decoration: BoxDecoration(color: nc.surface, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                          speaker!.avatar.isNotEmpty ? speaker!.avatar : speaker!.name.characters.first,
                          style: const TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    Text(speaker!.name,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: nc.textPrimary)),
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
