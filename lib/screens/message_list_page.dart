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
    final sessions = await getIt<ChatStorage>().loadAll();
    final groups = await getIt<AgentGroupStorage>().loadAll();

    final items = <_ChatItem>[];

    // 单聊会话
    for (final s in sessions) {
      if (s.messages.isEmpty) continue;
      final lastMsg = s.messages.last;
      items.add(_ChatItem(
        id: s.id,
        name: s.title,
        lastMessage: lastMsg.isUser ? '你: ${lastMsg.text}' : lastMsg.text,
        time: DateTime.now(), // 使用当前时间作为占位
        isGroup: false,
      ));
    }

    // 群聊会话
    for (final g in groups) {
      if (g.messages.isEmpty) continue;
      final lastMsg = g.messages.last;
      items.add(_ChatItem(
        id: g.id,
        name: g.name,
        lastMessage: lastMsg.isUser ? '你: ${lastMsg.text}' : lastMsg.text,
        time: DateTime.now(), // 使用当前时间作为占位
        isGroup: true,
      ));
    }

    // 按时间排序
    items.sort((a, b) => b.time.compareTo(a.time));

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
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                    '暂无消息',
                    style: TextStyle(color: nc.textSecondary),
                  ),
                )
              : ListView.separated(
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
    );
  }

  void _openChat(_ChatItem item) {
    if (item.isGroup) {
      AppRouter.toGroupChat(context, groupId: item.id);
    } else {
      // 单聊暂时跳转到主聊天页
      AppRouter.toChat(context, sessionId: item.id);
    }
    _load();
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
              icon: PhosphorIconsRegular.userPlus,
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

/// 聊天列表项数据
class _ChatItem {
  final String id;
  final String name;
  final String lastMessage;
  final DateTime time;
  final bool isGroup;

  _ChatItem({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.isGroup,
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
                        item.name.characters.first,
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
