import '../models/note.dart';
import '../services/note_storage.dart';
import 'base_tool.dart';

/// 管理（列出/修改/删除）已有笔记。save_note 工具负责新建，本工具负责后续管理。
class ManageNoteTool extends AgentTool {
  @override String get name => 'manage_notes';
  @override bool get readOnly => false;

  @override
  String get description => '管理已有笔记：列出列表、修改内容、删除笔记。'
      '当用户要求查看笔记列表、修改某条笔记、删除笔记时使用本工具。'
      '注意：新建笔记请用 save_note 工具，本工具不负责新建。';

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

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String? ?? '';
    final storage = NoteStorage();
    final notes = await storage.loadAll();

    switch (action) {
      case 'list':
        if (notes.isEmpty) return '当前没有任何笔记。';
        final buf = StringBuffer('共 ${notes.length} 条笔记：\n\n');
        for (final n in notes) {
          buf.writeln('- [id: ${n.id}] ${n.title}');
          final s = n.summary.replaceAll('\n', ' ');
          if (s.isNotEmpty) buf.writeln('  摘要: $s');
          buf.writeln('  创建: ${n.createdAt.toIso8601String()}');
        }
        return buf.toString().trim();

      case 'update':
        final id = args['note_id'] as String?;
        if (id == null) return '错误: 修改笔记需要提供 note_id';
        final idx = notes.indexWhere((n) => n.id == id);
        if (idx < 0) return '错误: 找不到 id 为 $id 的笔记';
        final note = notes[idx];
        await storage.update(Note(
          id: note.id,
          title: (args['title'] as String?) ?? note.title,
          content: (args['content'] as String?) ?? note.content,
          createdAt: note.createdAt,
        ));
        return '笔记「${(args['title'] as String?) ?? note.title}」已更新';

      case 'delete':
        final id = args['note_id'] as String?;
        if (id == null) return '错误: 删除笔记需要提供 note_id';
        final note = notes.where((n) => n.id == id).firstOrNull;
        if (note == null) return '错误: 找不到 id 为 $id 的笔记';
        await storage.remove(id);
        return '笔记「${note.title}」已删除';

      default:
        return '错误: 未知操作 "$action"，支持的操作: list / update / delete';
    }
  }
}
