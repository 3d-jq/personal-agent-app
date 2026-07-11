import '../models/note.dart';
import '../core/service_locator.dart';
import '../services/note_storage.dart';
import 'base_tool.dart';
import 'notes_list_tool.g.dart';
import 'notes_read_tool.g.dart';
import 'notes_update_tool.g.dart';
import 'notes_delete_tool.g.dart';

/// 笔记管理工具。
///
/// 原 `manage_notes`（带 action 参数）已拆分为 4 个独立工具，各自独占调用配额
/// （[ToolRegistry] 的频率限制按工具名计，拆分后读/改/删/列互不挤占）：
/// - [NotesListTool]   列出全部笔记
/// - [NotesReadTool]   读取某条笔记正文
/// - [NotesUpdateTool] 修改某条笔记
/// - [NotesDeleteTool] 删除某条笔记
///
/// 新建笔记由独立的 [SaveNoteTool] / CreateRichNoteTool 负责。
abstract class _ManageNotesBase extends AgentTool {
  String get action;

  @override
  bool get readOnly => false;

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
    final storage = getIt<NoteStorage>();
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
          final hint = id == null ? '未提供 note_id' : '找不到 id 为 "$id" 的笔记';
          final list = _formatList(notes);
          return '$hint。当前笔记列表如下，请选择正确的 id 重新调用 notes_update：\n\n$list';
        }

        final note = notes[idx];
        await storage.update(
          Note(
            id: note.id,
            title: (args['title'] as String?) ?? note.title,
            content: (args['content'] as String?) ?? note.content,
            createdAt: note.createdAt,
          ),
        );
        return '笔记「${(args['title'] as String?) ?? note.title}」已更新\n\n当前笔记列表（更新后）：\n${_formatList(await storage.loadAll())}';

      case 'delete':
        final id = args['note_id'] as String?;
        final note = id != null
            ? notes.where((n) => n.id == id).firstOrNull
            : null;

        // 没给 id 或 id 无效 → 自动 list
        if (note == null) {
          final hint = id == null ? '未提供 note_id' : '找不到 id 为 "$id" 的笔记';
          final list = _formatList(notes);
          return '$hint。当前笔记列表如下，请选择正确的 id 重新调用 notes_delete：\n\n$list';
        }

        await storage.remove(id!);
        return '笔记「${note.title}」已删除\n\n当前笔记列表（删除后）：\n${_formatList(await storage.loadAll())}';

      case 'read':
        final id = args['note_id'] as String?;
        final note = id != null
            ? notes.where((n) => n.id == id).firstOrNull
            : null;

        // 没给 id 或 id 无效 → 自动 list，让 AI 在同轮看到可用 id 后重试
        if (note == null) {
          final hint = id == null ? '未提供 note_id' : '找不到 id 为 "$id" 的笔记';
          final list = _formatList(notes);
          return '$hint。当前笔记列表如下，请选择正确的 id 重新调用 notes_read：\n\n$list';
        }

        final buf = StringBuffer();
        buf.writeln('笔记「${note.title}」(id: ${note.id})');
        final updated = note.updatedAt != note.createdAt
            ? '｜更新: ${note.updatedAt.toIso8601String()}'
            : '';
        buf.writeln('创建: ${note.createdAt.toIso8601String()}$updated');
        buf.writeln();
        buf.write(note.content);
        return buf.toString();

      default:
        return '错误: 未知操作 "$action"，支持的操作: list / read / update / delete';
    }
  }
}

/// 列出全部笔记（id + 标题 + 摘要）。
class NotesListTool extends _ManageNotesBase {
  @override
  String get name => 'notes_list';
  @override
  String get action => 'list';
  @override
  String get description => notesListToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': <String, dynamic>{},
    'required': <String>[],
  };
}

/// 读取某条笔记的完整正文与元数据。
class NotesReadTool extends _ManageNotesBase {
  @override
  String get name => 'notes_read';
  @override
  String get action => 'read';
  @override
  String get description => notesReadToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'note_id': {
        'type': 'string',
        'description': '要读取的笔记 id（从 notes_list 结果获取）',
      },
    },
    'required': ['note_id'],
  };
}

/// 修改某条笔记的标题与正文。
class NotesUpdateTool extends _ManageNotesBase {
  @override
  String get name => 'notes_update';
  @override
  String get action => 'update';
  @override
  String get description => notesUpdateToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'note_id': {
        'type': 'string',
        'description': '要修改的笔记 id（从 notes_list 结果获取）',
      },
      'title': {'type': 'string', 'description': '修改后的新标题（可选）'},
      'content': {
        'type': 'string',
        'description': '修改后的新正文，支持 Markdown（可选）',
      },
    },
    'required': ['note_id'],
  };
}

/// 删除某条笔记。
class NotesDeleteTool extends _ManageNotesBase {
  @override
  String get name => 'notes_delete';
  @override
  String get action => 'delete';
  @override
  String get description => notesDeleteToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'note_id': {
        'type': 'string',
        'description': '要删除的笔记 id（从 notes_list 结果获取）',
      },
    },
    'required': ['note_id'],
  };
}
