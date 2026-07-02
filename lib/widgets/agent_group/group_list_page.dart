import 'package:flutter/material.dart';
import '../../core/agent_colors.dart';
import '../../core/app_router.dart';
import '../../models/agent.dart';
import '../../models/agent_group.dart';
import '../../services/agent_group_storage.dart';
import '../../core/service_locator.dart';
import '../../services/agent_storage.dart';

/// 群列表页
class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});
  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  List<AgentGroup> _groups = [];
  Map<String, Agent> _agentMap = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await getIt<AgentGroupStorage>().loadAll();
    final agents = await getIt<AgentStorage>().loadAll();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _agentMap = {for (final a in agents) a.id: a};
    });
  }

  Future<void> _openGroup(AgentGroup g) async {
    await AppRouter.toGroupChat(context, groupId: g.id);
    _load();
  }

  Future<void> _createGroup() async {
    final result = await AppRouter.editGroup(context);
    if (result != null) {
      final (group, _, _) = result;
      await getIt<AgentGroupStorage>().save(group);
      _openGroup(group);
    }
  }

  Future<void> _deleteGroup(AgentGroup g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除群'),
        content: Text('确定删除「${g.name}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(c, true);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await getIt<AgentGroupStorage>().delete(g.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Agent 群',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: nc.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Agent 库',
            icon: Icon(Icons.smart_toy_outlined, color: nc.textPrimary),
            onPressed: () => AppRouter.toAgentManage(context),
          ),
          IconButton(
            icon: Icon(Icons.add, color: nc.textPrimary),
            onPressed: _createGroup,
          ),
        ],
      ),
      body: _groups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_outlined, size: 56, color: nc.textDisabled),
                  const SizedBox(height: 12),
                  Text(
                    '还没有群，点击右上角 + 建一个',
                    style: TextStyle(color: nc.textSecondary),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _SectionHeader(title: '我的群组', nc: nc),
                _RoundedCard(
                  nc: nc,
                  children: List.generate(_groups.length, (i) {
                    final g = _groups[i];
                    final members = g.agentIds
                        .map((id) => _agentMap[id])
                        .whereType<Agent>()
                        .toList();
                    return _GroupItem(
                      group: g,
                      members: members,
                      nc: nc,
                      isLast: i == _groups.length - 1,
                      onTap: () => _openGroup(g),
                      onLongPress: () => _deleteGroup(g),
                    );
                  }),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final AgentColors nc;
  const _SectionHeader({required this.title, required this.nc});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: nc.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _RoundedCard extends StatelessWidget {
  final AgentColors nc;
  final List<Widget> children;
  const _RoundedCard({required this.nc, required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nc.divider),
      ),
      child: Column(children: children),
    );
  }
}

class _GroupItem extends StatelessWidget {
  final AgentGroup group;
  final List<Agent> members;
  final AgentColors nc;
  final bool isLast;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _GroupItem({
    required this.group,
    required this.members,
    required this.nc,
    this.isLast = false,
    this.onTap,
    this.onLongPress,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _MemberAvatars(members: members, nc: nc),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: nc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      members.isEmpty
                          ? '空群'
                          : members.map((a) => a.name).join('、'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: nc.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: nc.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberAvatars extends StatelessWidget {
  final List<Agent> members;
  final AgentColors nc;
  const _MemberAvatars({required this.members, required this.nc});
  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: nc.primarySurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.groups_outlined, color: nc.textSecondary, size: 18),
      );
    }
    return SizedBox(
      width: 36 + (members.take(3).length - 1) * 10.0,
      height: 36,
      child: Stack(
        children: List.generate(members.take(3).length, (i) {
          final a = members[i];
          return Positioned(
            left: i * 10.0,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: nc.primarySurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: nc.surface, width: 2),
              ),
              child: Text(
                a.avatar.isNotEmpty ? a.avatar : a.name.characters.first,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          );
        }),
      ),
    );
  }
}
