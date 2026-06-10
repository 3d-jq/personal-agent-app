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
    final nc = AgentColors.of(context);
    final width = MediaQuery.of(context).size.width;

    return SizedBox(
      width: width,
      child: Drawer(
        backgroundColor: const Color(0xFFF6F6F6),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                child: Text('DWeis', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: nc.textPrimary, height: 1.2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text('生成图片、视频能力来自 Agnes-AI', style: TextStyle(fontSize: 11, color: nc.textSecondary.withValues(alpha: 0.5))),
              ),

              // ── Menu card ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _Card(nc: nc, children: [
                  _CardItem(icon: Icons.library_books_outlined, label: '文件库', nc: nc),
                  _CardItem(icon: Icons.folder_outlined, label: '项目', nc: nc),
                  _CardItem(icon: Icons.apps_outlined, label: '应用', nc: nc),
                  _CardItem(icon: Icons.more_horiz, label: '更多', nc: nc, isLast: true),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Chat history ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('最近', style: TextStyle(fontSize: 13, color: nc.textSecondary, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: widget.sessions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(child: Text('暂无对话', style: TextStyle(fontSize: 13, color: nc.textSecondary.withValues(alpha: 0.5)))),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _Card(
                          nc: nc,
                          children: List.generate(widget.sessions.length, (i) {
                            final s = widget.sessions[i];
                            return _CardItem(
                              label: s.title,
                              isActive: s.id == widget.currentSessionId,
                              nc: nc,
                              isLast: i == widget.sessions.length - 1,
                              onTap: () { Navigator.of(context).pop(); widget.onSessionTap(s.id); },
                              onLongPress: () => _confirmDelete(s),
                            );
                          }),
                        ),
                      ),
              ),

              // ── Bottom bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                child: Row(children: [
                  _Pill(icon: Icons.search_rounded, nc: nc),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                    },
                    child: _Pill(icon: Icons.person_rounded, nc: nc),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () { Navigator.of(context).pop(); widget.onNewChat(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 1))],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.edit_outlined, size: 18, color: nc.textPrimary),
                        const SizedBox(width: 6),
                        Text('聊天', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: nc.textPrimary)),
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

// ── Card ──

class _Card extends StatelessWidget {
  final AgentColors nc;
  final List<Widget> children;
  const _Card({required this.nc, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 1))],
      ),
      child: Column(children: children),
    );
  }
}

// ── Card item ──

class _CardItem extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool isActive;
  final bool isLast;
  final AgentColors nc;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _CardItem({
    this.icon,
    required this.label,
    this.isActive = false,
    this.isLast = false,
    required this.nc,
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
          child: Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: isActive ? const Color(0xFF0F7B6C) : nc.textPrimary),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: isActive ? const Color(0xFF0F7B6C) : nc.textPrimary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: nc.textSecondary.withValues(alpha: 0.5)),
          ]),
        ),
      ),
    );
  }
}

// ── Bottom pill ──

class _Pill extends StatelessWidget {
  final IconData icon;
  final AgentColors nc;
  const _Pill({required this.icon, required this.nc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: Icon(icon, size: 18, color: nc.textPrimary),
    );
  }
}
