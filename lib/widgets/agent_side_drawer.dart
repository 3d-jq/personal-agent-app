import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../models/chat_session.dart';
import 'settings_page.dart';

class AgentSideDrawer extends StatefulWidget {
  final List<ChatSession> sessions;
  final String? currentSessionId;
  final ValueChanged<String> onSessionTap;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSessionDeleted;

  const AgentSideDrawer({
    super.key,
    this.sessions = const [],
    this.currentSessionId,
    required this.onSessionTap,
    required this.onNewChat,
    required this.onSessionDeleted,
  });

  @override
  State<AgentSideDrawer> createState() => _AgentSideDrawerState();
}

class _AgentSideDrawerState extends State<AgentSideDrawer> {
  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    final width = MediaQuery.of(context).size.width;

    return SizedBox(
      width: width,
      child: Drawer(
        backgroundColor: colors.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                child: Text(
                  'DWeis',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: colors.textPrimary, height: 1.2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text('个人助手', style: TextStyle(fontSize: 14, color: colors.textSecondary, height: 1.43)),
              ),

              // ── Menu items ──
              _MenuItem(icon: Icons.library_books_outlined, label: '文件库'),
              _MenuItem(icon: Icons.folder_outlined, label: '项目'),
              _MenuItem(icon: Icons.apps_outlined, label: '应用'),
              _MenuItem(icon: Icons.more_horiz, label: '更多'),

              const SizedBox(height: 8),
              Divider(height: 1, indent: 16, endIndent: 16, color: colors.divider),
              const SizedBox(height: 16),

              // ── Chat history ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('最近', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textSecondary)),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: widget.sessions.isEmpty
                    ? Center(
                        child: Text('暂无对话', style: TextStyle(fontSize: 13, color: colors.textSecondary.withValues(alpha: 0.5))),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: widget.sessions.map((s) => _RecentItem(
                          title: s.title,
                          isActive: s.id == widget.currentSessionId,
                          onTap: () { Navigator.of(context).pop(); widget.onSessionTap(s.id); },
                          onDelete: () => _confirmDelete(s),
                        )).toList(),
                      ),
              ),

              // ── Bottom bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                child: Row(children: [
                  _BottomPill(icon: Icons.search_rounded, colors: colors),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                    },
                    child: _BottomPill(icon: Icons.person_rounded, colors: colors),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onNewChat();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.primarySurface,
                        border: Border.all(color: colors.divider, width: 0.5),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.edit_outlined, size: 18, color: colors.textPrimary),
                        const SizedBox(width: 6),
                        Text('聊天', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(ChatSession s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定要删除「${s.title}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () { Navigator.pop(ctx); widget.onSessionDeleted(s.id); }, child: const Text('删除')),
        ],
      ),
    );
  }
}

// ── Menu item ──

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MenuItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        leading: Icon(icon, size: 20, color: colors.textPrimary),
        title: Text(label, style: TextStyle(fontSize: 15, color: colors.textPrimary, height: 1.47)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        hoverColor: colors.primarySurface,
        onTap: onTap ?? () => Navigator.of(context).pop(),
      ),
    );
  }
}

// ── Recent item ──

class _RecentItem extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecentItem({required this.title, required this.isActive, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        dense: true,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: isActive ? const Color(0xFF0F7B6C) : colors.textPrimary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            height: 1.43,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        hoverColor: colors.primarySurface,
        onTap: onTap,
        onLongPress: onDelete,
      ),
    );
  }
}

// ── Bottom icon pill ──

class _BottomPill extends StatelessWidget {
  final IconData icon;
  final AgentColors colors;

  const _BottomPill({required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: colors.primarySurface,
        border: Border.all(color: colors.divider, width: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, size: 18, color: colors.textPrimary),
    );
  }
}
