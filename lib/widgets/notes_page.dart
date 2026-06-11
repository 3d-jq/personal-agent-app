import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../models/note.dart';
import '../services/note_storage.dart';

class NotesPage extends StatefulWidget {
  final VoidCallback? onPop;
  const NotesPage({super.key, this.onPop});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _storage = NoteStorage();
  List<Note> _notes = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _notes = await _storage.loadAll();
    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.onPop?.call();
      },
      child: Scaffold(
        backgroundColor: nc.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: nc.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('笔记',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: nc.textPrimary)),
        centerTitle: true,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? _emptyState(nc)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _notes.length,
                  itemBuilder: (_, i) => _noteCard(_notes[i], nc),
                ),
      ),
    );
  }

  Widget _emptyState(AgentColors nc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.note_add_outlined, size: 48, color: nc.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('还没有笔记',
              style: TextStyle(fontSize: 15, color: nc.textSecondary.withValues(alpha: 0.6))),
          const SizedBox(height: 6),
          Text('在聊天中让 DWeis 帮你记录',
              style: TextStyle(fontSize: 13, color: nc.textSecondary.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _noteCard(Note note, AgentColors nc) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => _NoteDetail(note: note))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: nc.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: nc.textPrimary)),
              ),
              GestureDetector(
                onTap: () => _confirmDelete(note),
                child: Icon(Icons.close_rounded,
                    size: 18, color: nc.textSecondary.withValues(alpha: 0.5)),
              ),
            ]),
            if (note.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(note.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: nc.textSecondary, height: 1.5)),
            ],
            const SizedBox(height: 8),
            Text(_formatTime(note.updatedAt),
                style: TextStyle(
                    fontSize: 11,
                    color: nc.textSecondary.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定要删除「${note.title}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _storage.remove(note.id);
              _load();
            },
            child: const Text('删除'),
          ),
        ],
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
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _NoteDetail extends StatelessWidget {
  final Note note;
  const _NoteDetail({required this.note});

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
        title: Text(note.title,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: nc.textPrimary)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${note.createdAt.year}/${note.createdAt.month.toString().padLeft(2, '0')}/${note.createdAt.day.toString().padLeft(2, '0')} '
              '${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')} 创建',
              style: TextStyle(
                  fontSize: 12, color: nc.textSecondary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            Text(note.content,
                style: TextStyle(
                    fontSize: 15, color: nc.textPrimary, height: 1.7)),
          ],
        ),
      ),
    );
  }
}
