import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/agent_colors.dart';
import '../../models/agent.dart';
import '../../models/agent_group.dart';
import '../../models/chat_message.dart';
import '../../services/agent_group_storage.dart';
import '../../services/agent_runner.dart';
import '../../services/agent_storage.dart';
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
  final List<StreamSubscription<String>> _activeSubs = [];

  // ── 滚动节流 ──
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _load();
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
      MaterialPageRoute(
        builder: (_) => GroupEditPage(existing: g),
        fullscreenDialog: true,
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
    if (_scrollTimer?.isActive ?? false) return;
    _scrollTimer = Timer(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
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

    // 没 @ 任何人 → 协调者自动响应
    if (mentionAgents.isEmpty && _coordinator != null) {
      mentionAgents.add(_coordinator!);
    } else if (mentionAgents.isEmpty) {
      await _saveGroup();
      return;
    }

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

    // ── 协作引擎 ──
    setState(() => _busy = true);
    _stopped = false;
    try {
      final handled = <String>{};
      const maxRounds = 10;
      var rounds = 0;

      // 第一轮：并发
      final firstRound = <Agent>[...mentionAgents];
      for (final a in firstRound) { handled.add(a.id); }
      final firstRoundResults = await _runBatch(firstRound);
      if (_stopped) return;

      // 扫描 @ 接力
      final nextPending = <Agent>[];
      for (var i = 0; i < firstRoundResults.length; i++) {
        if (_stopped) break;
        final nextMentionNames = parseMentions(firstRoundResults[i], _members);
        for (final name in nextMentionNames) {
          final nextAgent = _byName[name];
          if (nextAgent != null && !handled.contains(nextAgent.id)) {
            nextPending.add(nextAgent);
          }
        }
      }

      // 串行接力
      while (nextPending.isNotEmpty && rounds < maxRounds && !_stopped) {
        rounds++;
        final agent = nextPending.removeAt(0);
        if (handled.contains(agent.id)) continue;
        handled.add(agent.id);

        final results = await _runBatch([agent]);
        if (_stopped || results.isEmpty) break;

        final nextMentionNames = parseMentions(results.first, _members);
        for (final name in nextMentionNames) {
          final nextAgent = _byName[name];
          if (nextAgent != null && !handled.contains(nextAgent.id)) {
            nextPending.add(nextAgent);
          }
        }
      }
    } finally {
      setState(() => _busy = false);
      await _saveGroup();
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
    late final StreamSubscription<String> sub;
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
      );
      final completer = Completer<void>();
      sub = stream.listen(
        (chunk) {
          buf.write(chunk);
          placeholder.text = buf.toString();
          setState(() {});
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
      _activeSubs.add(sub);
      await completer.future;
    } finally {
      await sub.cancel();
      _activeSubs.remove(sub);
      placeholder.isStreaming = false;
    }
    setState(() {});
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
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: nc.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: nc.divider, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 4),
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
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          focusNode: _inputFocus,
                          minLines: 1, maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          style: TextStyle(fontSize: 15, color: nc.textPrimary),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) {
                            if (_inputCtrl.text.trim().isNotEmpty && !_busy) _send();
                          },
                          decoration: InputDecoration(
                            hintText: _members.isEmpty ? '先把 Agent 拉进群再说' : '说点什么，@名字 来召唤 Agent',
                            hintStyle: TextStyle(color: nc.textSecondary.withValues(alpha: 0.6), fontSize: 15),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
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
                      const SizedBox(width: 4),
                    ],
                  ),
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
