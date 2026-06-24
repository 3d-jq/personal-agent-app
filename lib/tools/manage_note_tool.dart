import '../models/note.dart';
import '../services/note_storage.dart';
import 'base_tool.dart';
import 'manage_note_tool.g.dart';

/// 管理（列出/修改/删除）已有笔记。save_note 工具负责新建，本工具负责后续管理。
class ManageNoteTool extends AgentTool {
  @override String get name => 'manage_notes';
  @override bool get readOnly => false;

  @override
  String get description => manageNoteToolDescription;

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['list', 'update', 'delete'],
            'description': 'list=列出全部笔记；update=修改某条笔记；delete=删除某条笔记',
          },
          'note_id': {
            'type': 'string',
            'description': '要修改/删除的笔记 id（update/delete 时必填，从 list 结果获取）',
          },
          'title': {
            'type': 'string',
            'description': '修改后的新标题（update 时可选）',
          },
          'content': {
            'type': 'string',
            'description': '修改后的新正文，支持 Markdown（update 时可选）',
          },
        },
        'required': ['action'],
      };

  /// 格式化笔记列表为紧凑文本，方便 AI 在 update/delete 失败时快速定位 id。
  static String _formatList(List<Note> notes) {
    if (notes.isEmpty) return '(空)';
    final buf = StringBuffer('共 ${notes.length} 条笔记：\n\n');
    for (final n in notes) {
      buf.writeln('- [id: ${n.id}] ${n.title}');
      final s = n.summary.replaceAll('\n', ' ');
      if (s.isNotEmpty) buf.writeln('  摘要: $s');
      buf.writeln('  创建: ${n.createdAt.toIso8601String()}');
    }
    return buf.toString().trim();
  }

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String? ?? '';
    final storage = NoteStorage();
    final notes = await storage.loadAll();

    switch (action) {
      case 'list':
        if (notes.isEmpty) return '当前没有任何笔记。';
        return _formatList(notes);

      case 'update':
        final id = args['note_id'] as String?;
        final idx = id != null ? notes.indexWhere((n) => n.id == id) : -1;

        // 没给 id 或 id 无效 → 自动 list，让 AI 在同轮看到可用 id 后重试
        if (id == null || idx < 0) {
          final hint = id == null
              ? '未提供 note_id'
              : '找不到 id 为 "$id" 的笔记';
          final list = _formatList(notes);
          return '$hint。当前笔记列表如下，请选择正确的 id 重新调用 update：\n\n$list';
        }

        final note = notes[idx];
        await storage.update(Note(
          id: note.id,
          title: (args['title'] as String?) ?? note.title,
          content: (args['content'] as String?) ?? note.content,
          createdAt: note.createdAt,
        ));
        return '笔记「${(args['title'] as String?) ?? note.title}」已更新\n\n当前笔记列表（更新后）：\n${_formatList(await storage.loadAll())}';

      case 'delete':
        final id = args['note_id'] as String?;
        final note = id != null ? notes.where((n) => n.id == id).firstOrNull : null;

        // 没给 id 或 id 无效 → 自动 list
        if (note == null) {
          final hint = id == null
              ? '未提供 note_id'
              : '找不到 id 为 "$id" 的笔记';
          final list = _formatList(notes);
          return '$hint。当前笔记列表如下，请选择正确的 id 重新调用 delete：\n\n$list';
        }

        await storage.remove(id!);
        return '笔记「${note.title}」已删除\n\n当前笔记列表（删除后）：\n${_formatList(await storage.loadAll())}';

      default:
        return '错误: 未知操作 "$action"，支持的操作: list / update / delete';
    }
  }
}
