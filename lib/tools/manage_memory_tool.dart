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
      '删除/修改时可以直接提供 content 关键词（无需记忆 id），工具会自动匹配。'
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
            'description': '要修改/删除的记忆 id（可选；如果记不住 id，可以直接传 content 关键词）',
          },
          'content': {
            'type': 'string',
            'description': 'delete 时：要删除记忆的内容关键词；update 时：修改后的新内容',
          },
        },
        'required': ['action'],
      };

  /// 格式化记忆列表为紧凑文本，方便 AI 在 update/delete 失败时快速定位 id。
  static String _formatList(List<MemoryEntry> memories) {
    if (memories.isEmpty) return '(空)';
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
  }

  /// 按 id 或内容关键词查找记忆。优先精确匹配 id；id 无效时按 content 关键词模糊匹配。
  static MemoryEntry? _findEntry(List<MemoryEntry> memories, String? id, String? content) {
    // 优先按 id
    if (id != null && id.isNotEmpty) {
      final byId = memories.where((e) => e.id == id).firstOrNull;
      if (byId != null) return byId;
    }
    // id 无效时按 content 关键词匹配
    if (content == null || content.isEmpty) return null;
    final keyword = content.toLowerCase();
    final matches = memories
        .where((e) => e.content.toLowerCase().contains(keyword))
        .toList();
    if (matches.length == 1) return matches.first;
    return null;
  }

  /// 返回匹配失败时的提示，列出所有记忆供 AI 选择。
  static String _notFoundHint(String? id, String? content, List<MemoryEntry> memories) {
    final list = _formatList(memories);
    if (id != null && id.isNotEmpty) {
      return '找不到 id 为 "$id" 的记忆，且未提供有效 content 关键词。当前记忆列表如下，请重新操作：\n\n$list';
    }
    if (content == null || content.isEmpty) {
      return '未提供 memory_id 或 content。当前记忆列表如下，请重新操作：\n\n$list';
    }
    final keyword = content.toLowerCase();
    final matches = memories.where((e) => e.content.toLowerCase().contains(keyword)).toList();
    if (matches.isEmpty) {
      return '未找到包含 "$content" 的记忆。当前记忆列表如下，请重新操作：\n\n$list';
    }
    final buf = StringBuffer('找到 ${matches.length} 条包含 "$content" 的记忆，请指定其中一条的 id 再操作：\n');
    for (final e in matches) {
      buf.writeln('- [id: ${e.id}] ${e.content}');
    }
    return buf.toString().trim();
  }

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String? ?? '';
    final storage = MemoryStorage();
    final memories = await storage.loadAll();

    switch (action) {
      case 'list':
        if (memories.isEmpty) return '当前没有任何记忆。';
        return _formatList(memories);

      case 'update':
        final id = (args['memory_id'] as String?)?.trim();
        final content = (args['content'] as String?)?.trim();
        final entry = _findEntry(memories, id, content);

        if (entry == null) {
          return _notFoundHint(id, content, memories);
        }

        // 如果提供了 id 且 content 是目标内容而非新内容，需要用户提供新内容
        if (id != null && id.isNotEmpty &&
            content != null && content.isNotEmpty &&
            entry.content.toLowerCase().contains(content.toLowerCase())) {
          return '请提供修改后的新内容（content 参数）。你要修改的记忆是：「${entry.content}」';
        }

        if (content == null || content.isEmpty) {
          return '错误: 修改记忆需要提供新的 content。当前该记忆内容为「${entry.content}」，请提供修改后的新内容。';
        }

        await storage.update(MemoryEntry(
          id: entry.id,
          type: entry.type,
          content: content,
          createdAt: entry.createdAt,
        ));
        final updated = await storage.loadAll();
        return '记忆已更新: $content\n\n当前记忆列表（更新后）：\n${_formatList(updated)}';

      case 'delete':
        final id = (args['memory_id'] as String?)?.trim();
        final content = (args['content'] as String?)?.trim();
        final entry = _findEntry(memories, id, content);

        if (entry == null) {
          return _notFoundHint(id, content, memories);
        }

        await storage.remove(entry.id);
        final remaining = await storage.loadAll();
        return '记忆「${entry.content}」已删除\n\n当前记忆列表（删除后）：\n${_formatList(remaining)}';

      default:
        return '错误: 未知操作 "$action"，支持的操作: list / update / delete';
    }
  }
}
