import 'package:flutter/foundation.dart';
import '../models/memory_entry.dart';
import '../services/memory_storage.dart';
import '../tools/base_tool.dart';

class SaveMemoryTool extends AgentTool {
  @override String get name => 'save_memory';
  @override bool get readOnly => false;

  @override
  String get description => '''
保存用户的事实或偏好，用于个性化服务。当用户表达了需要记住的信息、个人习惯、喜好、计划、身份相关事实时调用。
- fact: 用户让你记住的事实（如"我下周五有考试"、"我住在上海"）
- preference: 用户的偏好或习惯（如"我喜欢简洁的回答"、"不要叫我亲"）''';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'type': {
        'type': 'string',
        'description': '记忆类型: fact(事实) 或 preference(偏好)',
        'enum': ['fact', 'preference'],
      },
      'content': {
        'type': 'string',
        'description': '记忆内容，用简洁的一句话表达',
      },
    },
    'required': ['type', 'content'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final type = (args['type'] as String?)?.trim();
    final content = (args['content'] as String?)?.trim();
    if (type == null || type.isEmpty || content == null || content.isEmpty) {
      return '错误: 请提供有效的记忆类型和内容';
    }

    final memType = type == 'preference' ? MemoryType.preference : MemoryType.fact;
    final storage = MemoryStorage();

    // Deduplicate: skip if same content already exists
    final all = await storage.loadAll();
    if (all.any((e) => e.type == memType && e.content == content)) {
      return '已存在相同记忆，跳过。';
    }

    final entry = MemoryEntry(
      id: await storage.nextId(),
      type: memType,
      content: content,
    );
    await storage.add(entry);

    if (kDebugMode) {
      debugPrint('[SaveMemoryTool] 保存成功: type=$type, content=$content, total=${all.length + 1}');
    }

    final label = memType == MemoryType.preference ? '偏好' : '记忆';
    final tab = memType == MemoryType.preference ? '我的喜好' : '我的记忆';
    return '已保存[$label]到「$tab」: $content';
  }
}
