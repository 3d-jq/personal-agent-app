import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../core/app_config.dart';
import '../core/design_tokens.dart';
import '../core/app_router.dart';
import '../models/chat_session.dart';
import '../core/service_locator.dart';
import '../services/export_service.dart';

class AgentSideDrawer extends StatefulWidget {
  final List<ChatSession> sessions;
  final String? currentSessionId;
  final bool isLoading;
  final ValueChanged<String> onSessionTap;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSessionDeleted;
  /// 平推模式下关闭侧边栏的回调。非 null 时组件去掉 [Drawer] 壳、用此回调代替 Navigator.pop()。
  final VoidCallback? onClose;

  const AgentSideDrawer({
    super.key,
    this.sessions = const [],
    this.currentSessionId,
    this.isLoading = false,
    required this.onSessionTap,
    required this.onNewChat,
    required this.onSessionDeleted,
    this.onClose,
  });

  @override
  State<AgentSideDrawer> createState() => _AgentSideDrawerState();
}

class _AgentSideDrawerState extends State<AgentSideDrawer> {
  bool get _isPush => widget.onClose != null;

  void _closeAnd(void Function(BuildContext rootContext) action) {
    HapticFeedback.lightImpact();
    if (_isPush) {
      widget.onClose!();
      // 平推模式：侧边栏自身不占路由，直接在原页面执行导航。
      action(context);
    } else {
      final navigator = Navigator.of(context);
      final rootContext = navigator.context;
      navigator.pop();
      WidgetsBinding.instance.addPostFrameCallback((_) => action(rootContext));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    Widget content = SafeArea(
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        AppConfig.appName,
                        style: TextStyle(
                          fontSize: FontToken.display,
                          fontWeight: WeightToken.bold,
                          color: nc.textPrimary,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (_isPush)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onClose!();
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: nc.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.close, size: 18, color: nc.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text(
                  '生成图片、视频能力来自 Agnes-AI',
                  style: TextStyle(
                    fontSize: FontToken.micro,
                    color: nc.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ),

              // ── Menu card ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _Card(
                  nc: nc,
                  children: [
                    _CardItem(
                      icon: Icons.note,
                      label: '笔记',
                      nc: nc,
                      onTap: () => _closeAnd((ctx) => AppRouter.toNotes(ctx)),
                    ),
                    _CardItem(
                      icon: Icons.photo_library,
                      label: '图视',
                      nc: nc,
                      onTap: () => _closeAnd((ctx) => AppRouter.toMedia(ctx)),
                    ),
                    _CardItem(
                      icon: Icons.extension,
                      label: 'Skill & MCP',
                      nc: nc,
                      onTap: () => _closeAnd((ctx) => AppRouter.toSkillMcp(ctx)),
                    ),
                    _CardItem(
                      icon: Icons.group,
                      label: 'Agent 群',
                      nc: nc,
                      isLast: true,
                      onTap: () =>
                          _closeAnd((ctx) => AppRouter.toAgentHome(ctx)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Chat history ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '最近',
                  style: TextStyle(
                    fontSize: 13,
                    color: nc.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _Card(
                    nc: nc,
                    children: [
                      if (widget.sessions.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              '暂无对话',
                              style: TextStyle(
                                fontSize: 13,
                                color: nc.textSecondary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: widget.sessions.length,
                            itemBuilder: (context, i) {
                              final s = widget.sessions[i];
                              return _CardItem(
                                label: s.title,
                                isActive: s.id == widget.currentSessionId,
                                isCurrentLoading:
                                    widget.isLoading &&
                                    s.id == widget.currentSessionId,
                                nc: nc,
                                isLast: i == widget.sessions.length - 1,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (_isPush) {
                                    widget.onClose!();
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                  widget.onSessionTap(s.id);
                                },
                                onLongPress: () => _confirmDelete(s),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Bottom bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _closeAnd((ctx) => AppRouter.toSearch(ctx)),
                      child: _Pill(icon: Icons.search, nc: nc),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          _closeAnd((ctx) => AppRouter.toSettings(ctx)),
                      child: _Pill(icon: Icons.settings, nc: nc),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final text = await getIt<ExportService>()
                            .exportAllChatsAsJson();
                        await getIt<ExportService>().shareText(
                          text,
                          'dewis_chats.json',
                        );
                      },
                      child: _Pill(icon: Icons.download, nc: nc),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (_isPush) {
                          widget.onClose!();
                        } else {
                          Navigator.of(context).pop();
                        }
                        widget.onNewChat();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: nc.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '新对话',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),  // close Column
        );    // close SafeArea + end assignment

    // 平推模式：侧边栏作为独立区域渲染，不由 Drawer 管理，不加壳。
    // Material 包装确保主题继承正常（避免缺少祖先导致黄色下划线等异常），
    // 同时加水平拖拽手势让用户能从左往右滑关闭侧边栏。
    if (_isPush) {
      return Material(color: nc.background, child: content);
    }
    return Drawer(backgroundColor: nc.background, child: content);
  }

  void _confirmDelete(ChatSession s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定要删除「${s.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onSessionDeleted(s.id);
            },
            child: const Text('删除'),
          ),
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
        color: nc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nc.divider, width: 0.5),
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
  final bool isCurrentLoading;
  final bool isLast;
  final AgentColors nc;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _CardItem({
    this.icon,
    required this.label,
    this.isActive = false,
    this.isCurrentLoading = false,
    this.isLast = false,
    required this.nc,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: PressableScale(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: nc.textPrimary),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: nc.textPrimary,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (isCurrentLoading)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: nc.textSecondary,
                          ),
                        ),
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

// ── Bottom pill ──

class _Pill extends StatelessWidget {
  final IconData icon;
  final AgentColors nc;
  const _Pill({required this.icon, required this.nc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 18, color: nc.textPrimary),
    );
  }
}
