import 'package:uuid/uuid.dart';
import '../models/memory_entry.dart';
import '../services/memory_storage.dart';
import '../tools/base_tool.dart';

class SaveMemoryTool extends AgentTool {
  @override
  String get name => 'save_memory';

  @override
  String get description => '''
保存用户的记忆。分两种类型：
- fact: 用户让你记住的事实（"我下周五有考试"、"我的项目截止日期是3月20号"）
- preference: 用户的偏好或习惯（"我喜欢简洁的回答"、"我常用Python编程"、"我在学日语"）

当你注意到用户在表达偏好、习惯、或让你记住某件事时，主动调用此工具保存。
对于偏好类记忆，如果用户表达了新的偏好但与已有偏好可能冲突，先调用此工具保存，系统会自动去重。
严禁在未真正调用本工具的情况下对用户声称"已记住/我记下了/已经保存到记忆"——必须先调用本工具并看到成功返回，才能告知用户已完成。''';

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
    final type = args['type'] as String?;
    final content = args['content'] as String?;
    if (type == null || content == null) return '错误: 请提供记忆类型和内容';

    final memType = type == 'preference' ? MemoryType.preference : MemoryType.fact;
    final storage = MemoryStorage();

    // Deduplicate: skip if same content already exists
    final all = await storage.loadAll();
    if (all.any((e) => e.type == memType && e.content == content)) {
      return '已存在相同记忆，跳过。';
    }

    await storage.add(MemoryEntry(
      id: const Uuid().v4(),
      type: memType,
      content: content,
    ));

    final label = memType == MemoryType.preference ? '偏好' : '记忆';
    return '已保存[$label]: $content';
  }
}
