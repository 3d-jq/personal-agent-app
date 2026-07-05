import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/agent_colors.dart';
import '../core/app_router.dart';
import '../core/service_locator.dart';
import '../models/agent.dart';
import '../models/agent_group.dart';
import '../services/agent_group_storage.dart';
import '../services/agent_storage.dart';

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
      appBar: AppBar(
        backgroundColor: nc.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Agent',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: nc.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(PhosphorIconsRegular.plusCircle, color: nc.textPrimary),
            onPressed: _showAddMenu,
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // 群聊入口
                if (_groups.isNotEmpty) ...[
                  _SectionHeader(title: '群聊', nc: nc, count: _groups.length),
                  ..._groups.map((g) => _GroupTile(
                    group: g,
                    nc: nc,
                    onTap: () {
                      AppRouter.toGroupChat(context, groupId: g.id);
                      _load();
                    },
                  )),
                  Divider(height: 1, thickness: 0.5, color: nc.divider, indent: 16),
                ],
                // Agent 列表
                _SectionHeader(title: 'Agent', nc: nc, count: _agents.length),
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
        onChat: () {
          Navigator.pop(context);
          AppRouter.toAgentChat(context, agent);
        },
        onEdit: () {
          Navigator.pop(context);
          AppRouter.toAgentManage(context);
        },
      ),
    );
  }

  void _showAddMenu() {
    final nc = AgentColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: nc.surface,
          borderRadius: BorderRadius.circular(16),
        ),
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
            _AddMenuItem(
              icon: PhosphorIconsRegular.robot,
              label: '新建 Agent',
              nc: nc,
              onTap: () {
                Navigator.pop(context);
                AppRouter.toAgentManage(context);
              },
            ),
            Divider(height: 1, thickness: 0.5, color: nc.divider, indent: 16),
            _AddMenuItem(
              icon: PhosphorIconsRegular.users,
              label: '创建群聊',
              nc: nc,
              onTap: () {
                Navigator.pop(context);
                AppRouter.toGroupList(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: nc.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(PhosphorIconsRegular.users, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.name,
                  style: TextStyle(
                    fontSize: 16,
                    color: nc.textPrimary,
                  ),
                ),
              ),
              Icon(
                PhosphorIconsRegular.caretRight,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: nc.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: nc.divider, width: 0.5),
                ),
                child: Text(
                  agent.avatar.isNotEmpty ? agent.avatar : agent.name.characters.first,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: nc.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: TextStyle(
                        fontSize: 16,
                        color: nc.textPrimary,
                      ),
                    ),
                    if (agent.role.isNotEmpty)
                      Text(
                        agent.role,
                        style: TextStyle(
                          fontSize: 13,
                          color: nc.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(
                PhosphorIconsRegular.caretRight,
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
  final VoidCallback onChat;
  final VoidCallback onEdit;

  const _AgentCardSheet({
    required this.agent,
    required this.nc,
    required this.onChat,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(20),
      ),
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
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: nc.primarySurface,
                    borderRadius: BorderRadius.circular(12),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: nc.textPrimary,
                        ),
                      ),
                      if (agent.role.isNotEmpty)
                        Text(
                          agent.role,
                          style: TextStyle(
                            fontSize: 14,
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
                  child: ElevatedButton.icon(
                    onPressed: onChat,
                    icon: const Icon(PhosphorIconsRegular.chatCircle, size: 18),
                    label: const Text('发消息'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: nc.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Icon(PhosphorIconsRegular.pencilSimple, size: 18, color: nc.textPrimary),
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

/// 区域标题
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final AgentColors nc;

  const _SectionHeader({
    required this.title,
    required this.nc,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: nc.textSecondary,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text(
              '($count)',
              style: TextStyle(fontSize: 13, color: nc.textDisabled),
            ),
          ],
        ],
      ),
    );
  }
}

/// 添加菜单项
class _AddMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final AgentColors nc;
  final VoidCallback onTap;

  const _AddMenuItem({
    required this.icon,
    required this.label,
    required this.nc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: nc.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(fontSize: 16, color: nc.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
