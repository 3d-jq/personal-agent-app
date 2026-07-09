import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../core/design_tokens.dart';
import '../core/app_router.dart';
import '../core/service_locator.dart';
import '../models/agent.dart';
import '../models/agent_group.dart';
import '../services/agent_group_storage.dart';
import '../services/agent_storage.dart';
import '../widgets/common_widgets.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_placeholder.dart';

/// Agent 通讯录页面（类似微信通讯录）
class AgentContactPage extends StatefulWidget {
  const AgentContactPage({super.key});

  @override
  State<AgentContactPage> createState() => _AgentContactPageState();
}

class _AgentContactPageState extends State<AgentContactPage> {
  List<Agent> _agents = [];
  List<AgentGroup> _groups = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final agents = await getIt<AgentStorage>().loadAll();
    final groups = await getIt<AgentGroupStorage>().loadAll();
    setState(() {
      _agents = agents;
      _groups = groups;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppTopBar(
        title: 'Agent',
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: nc.textPrimary),
            onPressed: _showAddMenu,
          ),
        ],
      ),
      body: !_loaded
          ? const AgentListSkeleton()
          : (_agents.isEmpty && _groups.isEmpty)
              ? StatePlaceholder.empty(
                  icon: Icons.smart_toy_outlined,
                  title: '还没有 Agent',
                  subtitle: '点击右上角 + 创建你的第一个 Agent',
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                // 群聊入口
                if (_groups.isNotEmpty) ...[
                  SectionHeader(title: '群聊', nc: nc, count: _groups.length),
                  ..._groups.map((g) => _GroupTile(
                    group: g,
                    nc: nc,
                    onTap: () => _showGroupCard(g),
                  )),
                  Divider(height: 0.5, thickness: 0.5, color: nc.divider, indent: SpaceToken.lg),
                ],
                // Agent 列表
                SectionHeader(title: 'Agent', nc: nc, count: _agents.length),
                ..._agents.map((a) => _AgentTile(
                  agent: a,
                  nc: nc,
                  onTap: () => _showAgentCard(a),
                )),
              ],
            ),
    );
  }

  void _showAgentCard(Agent agent) {
    final nc = AgentColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AgentCardSheet(
        agent: agent,
        nc: nc,
        onDelete: () {
          Navigator.pop(context);
          _deleteAgent(agent);
        },
        onEdit: () async {
          Navigator.pop(context);
          final result = await AppRouter.editAgent(context, existing: agent);
          if (result != null) {
            await getIt<AgentStorage>().update(result);
            if (mounted) _load();
          }
        },
      ),
    );
  }

  void _deleteAgent(Agent agent) {
    final nc = AgentColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: nc.surface,
        title: Text('删除 Agent', style: TextStyle(color: nc.textPrimary)),
        content: Text('确定删除「${agent.name}」？', style: TextStyle(color: nc.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: nc.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // 从所有群中移除该 Agent
              final groups = await getIt<AgentGroupStorage>().loadAll();
              for (final g in groups) {
                if (g.agentIds.contains(agent.id)) {
                  g.agentIds.remove(agent.id);
                  await getIt<AgentGroupStorage>().save(g);
                }
              }
              await getIt<AgentStorage>().remove(agent.id);
              _load();
            },
            child: Text('删除', style: TextStyle(color: nc.error)),
          ),
        ],
      ),
    );
  }

  void _showGroupCard(AgentGroup group) {
    final nc = AgentColors.of(context);
    final memberNames = group.agentIds
        .map((id) => _agents.where((a) => a.id == id).firstOrNull)
        .whereType<Agent>()
        .map((a) => a.name)
        .join('、');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GroupCardSheet(
        group: group,
        memberNames: memberNames,
        nc: nc,
        onEdit: () async {
          Navigator.pop(context);
          final result = await AppRouter.editGroup(context, existing: group);
          if (result != null) {
            await getIt<AgentGroupStorage>().save(result);
            if (mounted) _load();
          }
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteGroup(group);
        },
      ),
    );
  }

  void _deleteGroup(AgentGroup group) {
    final nc = AgentColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: nc.surface,
        title: Text('删除群聊', style: TextStyle(color: nc.textPrimary)),
        content: Text('确定删除「${group.name}」？', style: TextStyle(color: nc.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: nc.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await getIt<AgentGroupStorage>().delete(group.id);
              _load();
            },
            child: Text('删除', style: TextStyle(color: nc.error)),
          ),
        ],
      ),
    );
  }

  void _showAddMenu() {
    final nc = AgentColors.of(context);
    showAddMenu(context, nc, [
      AddMenuItem(
        icon: Icons.smart_toy_outlined,
        label: '新建 Agent',
        nc: nc,
        onTap: () async {
          Navigator.pop(context);
          final result = await AppRouter.editAgent(context);
          if (result != null) {
            await getIt<AgentStorage>().add(result);
            _load();
          }
        },
      ),
    ]);
  }
}

/// 群聊列表项
class _GroupTile extends StatelessWidget {
  final AgentGroup group;
  final AgentColors nc;
  final VoidCallback onTap;

  const _GroupTile({
    required this.group,
    required this.nc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: nc.fillTertiary,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpaceToken.lg,
            vertical: SpaceToken.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: nc.primary,
                  borderRadius: BorderRadius.circular(RadiusToken.sm),
                ),
                child: Icon(Icons.group, size: 20, color: Colors.white),
              ),
              const SizedBox(width: SpaceToken.md),
              Expanded(
                child: Text(
                  group.name,
                  style: TextStyle(
                    fontSize: FontToken.body,
                    fontWeight: WeightToken.medium,
                    color: nc.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: nc.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Agent 列表项
class _AgentTile extends StatelessWidget {
  final Agent agent;
  final AgentColors nc;
  final VoidCallback onTap;

  const _AgentTile({
    required this.agent,
    required this.nc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: nc.fillTertiary,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpaceToken.lg,
            vertical: SpaceToken.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: nc.primarySurface,
                  borderRadius: BorderRadius.circular(RadiusToken.sm),
                  border: Border.all(color: nc.divider, width: 0.5),
                ),
                child: Text(
                  agent.avatar.isNotEmpty ? agent.avatar : agent.name.characters.first,
                  style: TextStyle(
                    fontSize: FontToken.body,
                    fontWeight: WeightToken.semibold,
                    color: nc.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: SpaceToken.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: TextStyle(
                        fontSize: FontToken.body,
                        fontWeight: WeightToken.medium,
                        color: nc.textPrimary,
                      ),
                    ),
                    if (agent.role.isNotEmpty)
                      Text(
                        agent.role,
                        style: TextStyle(
                          fontSize: FontToken.small,
                          color: nc.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: nc.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Agent 工牌弹窗
class _AgentCardSheet extends StatelessWidget {
  final Agent agent;
  final AgentColors nc;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _AgentCardSheet({
    required this.agent,
    required this.nc,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: SpaceToken.lg,
        right: SpaceToken.lg,
        bottom: MediaQuery.of(context).padding.bottom + SpaceToken.lg,
      ),
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(RadiusToken.xl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                padding: const EdgeInsets.all(SpaceToken.x2),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: nc.primarySurface,
                        borderRadius: BorderRadius.circular(RadiusToken.md),
                        border: Border.all(color: nc.divider, width: 0.5),
                      ),
                      child: Text(
                        agent.avatar.isNotEmpty ? agent.avatar : agent.name.characters.first,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: nc.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agent.name,
                            style: TextStyle(
                              fontSize: FontToken.headline,
                              fontWeight: WeightToken.semibold,
                              color: nc.textPrimary,
                            ),
                          ),
                          if (agent.role.isNotEmpty)
                            Text(
                              agent.role,
                              style: TextStyle(
                                fontSize: FontToken.body,
                                color: nc.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: nc.error,
                          side: BorderSide(color: nc.error.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(vertical: SpaceToken.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RadiusToken.md),
                          ),
                        ),
                        child: const Text('删除'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: nc.textPrimary,
                          side: BorderSide(color: nc.divider, width: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: SpaceToken.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RadiusToken.md),
                          ),
                        ),
                        child: const Text('编辑'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 群聊工牌弹窗
class _GroupCardSheet extends StatelessWidget {
  final AgentGroup group;
  final String memberNames;
  final AgentColors nc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GroupCardSheet({
    required this.group,
    required this.memberNames,
    required this.nc,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: SpaceToken.lg,
        right: SpaceToken.lg,
        bottom: MediaQuery.of(context).padding.bottom + SpaceToken.lg,
      ),
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(RadiusToken.xl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                padding: const EdgeInsets.all(SpaceToken.x2),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: nc.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.group, size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: TextStyle(
                              fontSize: FontToken.headline,
                              fontWeight: WeightToken.semibold,
                              color: nc.textPrimary,
                            ),
                          ),
                          if (memberNames.isNotEmpty)
                            Text(
                              memberNames,
                              style: TextStyle(
                                fontSize: FontToken.body,
                                color: nc.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            '${group.agentIds.length} 位成员',
                            style: TextStyle(
                              fontSize: FontToken.caption,
                              color: nc.textDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: nc.error,
                          side: BorderSide(color: nc.error.withValues(alpha: 0.3), width: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: SpaceToken.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RadiusToken.md),
                          ),
                        ),
                        child: const Text('删除'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: nc.textPrimary,
                          side: BorderSide(color: nc.divider, width: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: SpaceToken.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RadiusToken.md),
                          ),
                        ),
                        child: const Text('编辑'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
