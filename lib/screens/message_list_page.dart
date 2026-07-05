import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/agent_colors.dart';
import '../core/app_router.dart';
import '../core/service_locator.dart';
import '../models/agent.dart';
import '../models/agent_group.dart';
import '../models/chat_session.dart';
import '../services/agent_group_storage.dart';
import '../services/agent_storage.dart';
import '../services/chat_storage.dart';
import '../widgets/common_widgets.dart';
import '../widgets/state_placeholder.dart';

/// 消息列表页面（类似微信聊天列表）
class MessageListPage extends StatefulWidget {
  const MessageListPage({super.key});

  @override
  State<MessageListPage> createState() => _MessageListPageState();
}

class _MessageListPageState extends State<MessageListPage> {
  List<_ChatItem> _items = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 并行加载所有数据
    final results = await Future.wait([
      getIt<ChatStorage>().loadAll(),
      getIt<AgentGroupStorage>().loadAll(),
      getIt<AgentStorage>().loadAll(),
    ]);
    final sessions = results[0] as List<ChatSession>;
    final groups = results[1] as List<AgentGroup>;
    final agents = results[2] as List<Agent>;

    final items = <_ChatItem>[];

    // 所有 Agent（没有聊天记录的也显示）
    for (final a in agents) {
      // 查找是否有对应的聊天记录
      final session = sessions.where((s) => s.title == a.name).firstOrNull;
      final lastMsg = session != null && session.messages.isNotEmpty
          ? session.messages.last
          : null;

      items.add(_ChatItem(
        id: a.id,
        name: a.name,
        avatar: a.avatar,
        lastMessage: lastMsg != null
            ? (lastMsg.isUser ? '你: ${lastMsg.text}' : lastMsg.text)
            : a.role,
        time: session?.updatedAt ?? DateTime(2000),
        isGroup: false,
        agentId: a.id,
      ));
    }

    // 群聊（所有群都显示）
    for (final g in groups) {
      final lastMsg = g.messages.isNotEmpty ? g.messages.last : null;
      items.add(_ChatItem(
        id: g.id,
        name: g.name,
        avatar: '',
        lastMessage: lastMsg != null
            ? (lastMsg.isUser ? '你: ${lastMsg.text}' : lastMsg.text)
            : '暂无消息',
        time: g.updatedAt,
        isGroup: true,
      ));
    }

    // 按时间排序（有聊天记录的排前面）
    items.sort((a, b) {
      if (a.time == DateTime(2000) && b.time != DateTime(2000)) return 1;
      if (a.time != DateTime(2000) && b.time == DateTime(2000)) return -1;
      return b.time.compareTo(a.time);
    });

    setState(() {
      _items = items;
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
          '消息',
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
          ? StatePlaceholder.loading()
          : _items.isEmpty
              ? StatePlaceholder.empty(
                  icon: PhosphorIconsRegular.chatCircle,
                  title: '暂无消息',
                  subtitle: '点击右上角 + 创建群聊，或到 Agent 页面开始聊天',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: nc.divider,
                      indent: 72,
                    ),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _MessageTile(
                        item: item,
                        nc: nc,
                        onTap: () => _openChat(item),
                      );
                    },
                  ),
                ),
    );
  }

  void _openChat(_ChatItem item) async {
    if (item.isGroup) {
      await AppRouter.toGroupChat(context, groupId: item.id);
    } else if (item.agentId != null) {
      await _openAgentChat(item.agentId!);
    }
    // 返回后刷新数据
    if (mounted) _load();
  }

  Future<void> _openAgentChat(String agentId) async {
    final agents = await getIt<AgentStorage>().loadAll();
    final agent = agents.where((a) => a.id == agentId).firstOrNull;
    if (agent != null && mounted) {
      await AppRouter.toAgentChat(context, agent);
    }
  }

  void _showAddMenu() {
    final nc = AgentColors.of(context);
    showAddMenu(context, nc, [
      AddMenuItem(
        icon: PhosphorIconsRegular.users,
        label: '创建群聊',
        nc: nc,
        onTap: () async {
          Navigator.pop(context);
          final result = await AppRouter.editGroup(context);
          if (result != null) {
            await getIt<AgentGroupStorage>().save(result);
            _load();
          }
        },
      ),
    ]);
  }
}

/// 聊天列表项数据
class _ChatItem {
  final String id;
  final String name;
  final String avatar;
  final String lastMessage;
  final DateTime time;
  final bool isGroup;
  final String? agentId;

  _ChatItem({
    required this.id,
    required this.name,
    this.avatar = '',
    required this.lastMessage,
    required this.time,
    required this.isGroup,
    this.agentId,
  });
}

/// 消息列表项
class _MessageTile extends StatelessWidget {
  final _ChatItem item;
  final AgentColors nc;
  final VoidCallback onTap;

  const _MessageTile({
    required this.item,
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
              // 头像
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.isGroup ? nc.primary : nc.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item.isGroup
                    ? Icon(PhosphorIconsRegular.users, size: 24, color: Colors.white)
                    : Text(
                        item.avatar.isNotEmpty ? item.avatar : item.name.characters.first,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: nc.textPrimary,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // 消息内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: nc.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(item.time),
                          style: TextStyle(
                            fontSize: 12,
                            color: nc.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.lastMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: nc.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 7) return '${time.month}/${time.day}';
    if (diff.inDays > 0) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    }
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
    return '刚刚';
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
                style: TextStyle(
                  fontSize: 16,
                  color: nc.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
