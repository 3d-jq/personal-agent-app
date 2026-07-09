import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../core/agent_colors.dart';
import '../core/design_tokens.dart';
import '../core/app_router.dart';
import 'common_widgets.dart';
import 'app_toast.dart';
import '../models/note.dart';
import '../services/export_service.dart';
import '../services/note_export_service.dart';
import '../core/service_locator.dart';
import '../services/note_storage.dart';
import 'inline_content.dart';
import 'state_placeholder.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _storage = getIt<NoteStorage>();
  List<Note> _notes = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _storage.addListener(_onStorageChanged);
    _load();
  }

  @override
  void dispose() {
    _storage.removeListener(_onStorageChanged);
    super.dispose();
  }

  void _onStorageChanged() {
    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    try {
      _notes = await _storage.loadAll();
    } catch (_) {
      _notes = [];
    }
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppTopBar(
        title: '笔记',
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_notes.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.download,
                color: nc.textPrimary,
                size: 22,
              ),
              onPressed: () async {
                HapticFeedback.lightImpact();
                final text = await getIt<ExportService>().exportNotesAsText();
                await getIt<ExportService>().shareText(text, 'dewis_notes.txt');
              },
            ),
        ],
      ),
      body: !_loaded
          ? StatePlaceholder.loading()
          : _notes.isEmpty
          ? StatePlaceholder.empty(
              icon: Icons.edit_note,
              title: '还没有笔记',
              subtitle: '点击右下角 + 创建，或在聊天中让 DWeis 帮你记录',
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: SpaceToken.lg, vertical: SpaceToken.sm),
              itemCount: _notes.length,
              itemBuilder: (_, i) {
                final note = _notes[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: SpaceToken.sm),
                  child: Dismissible(
                    key: Key(note.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: SpaceToken.xl),
                      decoration: BoxDecoration(
                        color: nc.error,
                        borderRadius: BorderRadius.circular(RadiusToken.md),
                      ),
                      child: Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: nc.bgSubtle,
                          title: Text('删除笔记', style: TextStyle(color: nc.textPrimary)),
                          content: Text('确定删除「${note.title}」？', style: TextStyle(color: nc.textSecondary)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('取消', style: TextStyle(color: nc.textSecondary)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('删除', style: TextStyle(color: nc.error)),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) => _deleteNote(note),
                    child: _NoteTile(
                      note: note,
                      nc: nc,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        AppRouter.push(
                          context,
                          _NoteDetail(note: note, onEdit: () => _openEditor(note)),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _openEditor(null);
        },
        backgroundColor: nc.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _deleteNote(Note note) async {
    await _storage.remove(note.id);
    _load();
  }

  void _openEditor(Note? existing) {
    AppRouter.push(
      context,
      _NoteEditor(
        note: existing,
        onSaved: (note) async {
          if (existing != null) {
            await _storage.update(note);
          } else {
            await _storage.add(note);
          }
          await _load();
        },
      ),
    );
  }
}

class _NoteDetail extends StatelessWidget {
  final Note note;
  final VoidCallback? onEdit;
  const _NoteDetail({required this.note, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppTopBar(
        title: note.title,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (onEdit != null)
            IconButton(
              icon: Icon(Icons.edit, color: nc.textPrimary),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                onEdit!();
              },
            ),
          IconButton(
            icon: Icon(Icons.share, color: nc.textPrimary),
            onPressed: () async {
              HapticFeedback.lightImpact();
              try {
                await NoteExportService.exportToWord(note);
              } catch (e) {
                if (context.mounted) {
                  AppToast.show(context, '导出失败: $e', type: ToastType.error);
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(SpaceToken.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${note.createdAt.year}/${note.createdAt.month.toString().padLeft(2, '0')}/${note.createdAt.day.toString().padLeft(2, '0')} '
              '${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')} 创建',
              style: TextStyle(
                fontSize: FontToken.caption,
                color: nc.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: SpaceToken.lg),
            ...buildInlineContent(note.content, nc, context),
          ],
        ),
      ),
    );
  }
}

// ── Note Editor ──

class _NoteEditor extends StatefulWidget {
  final Note? note;
  final Future<void> Function(Note) onSaved;

  const _NoteEditor({this.note, required this.onSaved});

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final isEditing = widget.note != null;
    final top = MediaQuery.of(context).padding.top;
    // 让卡片至少撑满可视区域，呈现「一页纸」的写作质感
    final minH =
        MediaQuery.of(context).size.height - top - 48 - SpaceToken.md * 2;

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppTopBar(
        title: isEditing ? '编辑笔记' : '新建笔记',
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => _confirmDiscard(nc),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              '保存',
              style: TextStyle(
                fontSize: FontToken.body,
                color: nc.success,
                fontWeight: WeightToken.semibold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: SpaceToken.lg,
          vertical: SpaceToken.md,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minH),
          child: ElevatedCard(
            nc: nc,
            padding: EdgeInsets.all(SpaceToken.xl),
            borderRadius: BorderRadius.circular(RadiusToken.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleCtrl,
                  autofocus: !isEditing,
                  style: TextStyle(
                    fontSize: FontToken.headline,
                    fontWeight: WeightToken.semibold,
                    color: nc.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '标题',
                    hintStyle: TextStyle(
                      color: nc.textSecondary.withValues(alpha: 0.4),
                      fontSize: FontToken.headline,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: SpaceToken.md),
                  child: Divider(height: 0.5, thickness: 0.5, color: nc.divider),
                ),
                TextField(
                  controller: _contentCtrl,
                  focusNode: _focusNode,
                  maxLines: null,
                  minLines: 8,
                  style: TextStyle(
                    fontSize: FontToken.body,
                    color: nc.textPrimary,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: '开始写笔记…\n\n支持 Markdown 格式',
                    hintStyle: TextStyle(
                      color: nc.textSecondary.withValues(alpha: 0.4),
                      fontSize: FontToken.body,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    alignLabelWithHint: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(top: SpaceToken.lg),
                  child: Row(
                    children: [
                      Icon(
                        Icons.text_format,
                        size: 14,
                        color: nc.textSecondary.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '支持 Markdown 语法',
                        style: TextStyle(
                          fontSize: FontToken.caption,
                          color: nc.textSecondary.withValues(alpha: 0.45),
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
    );
  }

  void _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final now = DateTime.now();
    final note = widget.note != null
        ? (widget.note!
            ..title = title.isEmpty ? '无标题' : title
            ..content = content
            ..updatedAt = now)
        : Note(
            id: const Uuid().v4(),
            title: title.isEmpty ? '无标题' : title,
            content: content,
            createdAt: now,
            updatedAt: now,
          );

    try {
      await widget.onSaved(note);
      if (mounted) {
        AppToast.show(context, '已保存', type: ToastType.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, '保存失败: $e', type: ToastType.error);
      }
    }
  }

  void _confirmDiscard(AgentColors nc) {
    final hasChanges =
        _titleCtrl.text.isNotEmpty || _contentCtrl.text.isNotEmpty;
    if (!hasChanges || widget.note == null) {
      Navigator.pop(context);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃修改？'),
        content: const Text('未保存的更改将丢失'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('放弃', style: TextStyle(color: nc.error)),
          ),
        ],
      ),
    );
  }
}

/// 笔记列表项（带动画）
class _NoteTile extends StatefulWidget {
  final Note note;
  final AgentColors nc;
  final VoidCallback onTap;

  const _NoteTile({
    required this.note,
    required this.nc,
    required this.onTap,
  });

  @override
  State<_NoteTile> createState() => _NoteTileState();
}

class _NoteTileState extends State<_NoteTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.02, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nc = widget.nc;
    final note = widget.note;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ElevatedCard(
          nc: nc,
          shadow: nc.shadowSm,
          borderRadius: BorderRadius.circular(RadiusToken.md),
          padding: EdgeInsets.all(SpaceToken.lg),
          child: InkWell(
            onTap: widget.onTap,
            splashFactory: NoSplash.splashFactory,
            highlightColor: nc.fillTertiary,
            borderRadius: BorderRadius.circular(RadiusToken.md),
            child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: FontToken.title,
                            color: nc.textPrimary,
                            fontWeight: WeightToken.semibold,
                          ),
                        ),
                        const SizedBox(height: SpaceToken.xs),
                        Text(
                          note.summary.isEmpty
                              ? _formatTime(note.updatedAt)
                              : note.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: FontToken.body,
                            color: nc.textSecondary,
                          ),
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
        ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}
