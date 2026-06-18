import '../models/memory_entry.dart';
import '../services/memory_storage.dart';
import 'base_tool.dart';

/// 管理（列出/修改/删除）已有记忆。save_memory 工具负责新增，本工具负责后续管理。
class ManageMemoryTool extends AgentTool {
  @override String get name => 'manage_memory';
  @override bool get readOnly => false;

  @override
  String get description => '管理已有记忆：列出列表、修改内容、删除记忆。'
      '当用户要求查看记忆列表、修改某条记忆、删除记忆时使用本工具。'
      '注意：新建记忆请用 save_memory 工具，本工具不负责新建。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['list', 'update', 'delete'],
            'description': 'list=列出全部记忆；update=修改某条记忆；delete=删除某条记忆',
          },
          'memory_id': {
            'type': 'string',
            'description': '要修改/删除的记忆 id（update/delete 时必填，从 list 结果获取）',
          },
          'content': {
            'type': 'string',
            'description': '修改后的新内容（update 时必填）',
          },
        },
        'required': ['action'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String? ?? '';
    final storage = MemoryStorage();
    final memories = await storage.loadAll();

    switch (action) {
      case 'list':
        if (memories.isEmpty) return '当前没有任何记忆。';
        final facts = memories.where((e) => e.type == MemoryType.fact).toList();
        final prefs = memories.where((e) => e.type == MemoryType.preference).toList();
        final buf = StringBuffer();
        if (facts.isNotEmpty) {
          buf.writeln('【记忆/事实】(${facts.length} 条)');
          for (final e in facts) {
            buf.writeln('- [id: ${e.id}] ${e.content}');
          }
          buf.writeln();
        }
        if (prefs.isNotEmpty) {
          buf.writeln('【喜好/偏好】(${prefs.length} 条)');
          for (final e in prefs) {
            buf.writeln('- [id: ${e.id}] ${e.content}');
          }
        }
        return buf.toString().trim();

      case 'update':
        final id = args['memory_id'] as String?;
        if (id == null) return '错误: 修改记忆需要提供 memory_id';
        final idx = memories.indexWhere((e) => e.id == id);
        if (idx < 0) return '错误: 找不到 id 为 $id 的记忆';
        final content = args['content'] as String?;
        if (content == null || content.isEmpty) return '错误: 修改记忆需要提供新的 content';
        final old = memories[idx];
        await storage.update(MemoryEntry(
          id: old.id,
          type: old.type,
          content: content,
          createdAt: old.createdAt,
        ));
        return '记忆已更新: $content';

      case 'delete':
        final id = args['memory_id'] as String?;
        if (id == null) return '错误: 删除记忆需要提供 memory_id';
        final entry = memories.where((e) => e.id == id).firstOrNull;
        if (entry == null) return '错误: 找不到 id 为 $id 的记忆';
        await storage.remove(id);
        return '记忆「${entry.content}」已删除';

      default:
        return '错误: 未知操作 "$action"，支持的操作: list / update / delete';
    }
  }
}
