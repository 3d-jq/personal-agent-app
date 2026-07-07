import '../core/service_locator.dart';
import '../models/skill.dart';
import 'base_tool.dart';
import 'skill_registry.dart';
import 'skill_manage_tool.g.dart';

/// 技能管理工具：让 Agent 查看、创建和读取技能包
///
/// 采用渐进式披露：
/// - list: 列出所有 Skill（name + description）
/// - read: 读取 Skill 正文（SKILL.md 内容）
/// - read_cookbook: 读取 cookbook 详细步骤文件
/// - create: 创建新技能
/// - match: 关键词匹配
class SkillManageTool extends AgentTool {
  @override
  String get name => 'skill_manage';

  @override
  bool get readOnly => false;

  @override
  String get description => skillManageToolDescription;

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['list', 'read', 'read_cookbook', 'create', 'match'],
        'description': '操作类型',
      },
      'name': {
        'type': 'string',
        'description': '技能名称（read/read_cookbook/create 时必填）',
      },
      'description': {
        'type': 'string',
        'description': '技能描述，应包含触发场景说明（create 时必填）',
      },
      'instructions': {
        'type': 'string',
        'description': '技能指令正文：什么情况下使用、执行什么步骤、用哪些工具（create 时必填）',
      },
      'keywords': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': '触发关键词列表（create 时可选）',
      },
      'cookbook_files': {
        'type': 'object',
        'description': 'cookbook 文件映射（create 时可选），key=文件名 value=文件内容',
      },
      'file': {
        'type': 'string',
        'description': 'cookbook 文件名（read_cookbook 时必填）',
      },
      'content': {
        'type': 'string',
        'description': 'cookbook 文件内容（read_cookbook 时返回）',
      },
      'text': {'type': 'string', 'description': '用户输入文本（match 时使用）'},
    },
    'required': ['action'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String?;
    if (action == null) return '错误: 必须提供 action 参数';

    final registry = getIt<SkillRegistry>();

    switch (action) {
      case 'list':
        final skills = registry.all;
        if (skills.isEmpty) return '暂无可用 Skill';
        final buf = StringBuffer();
        for (final skill in skills) {
          buf.writeln('• ${skill.name}: ${skill.description}');
          if (skill.cookbookFiles.isNotEmpty) {
            buf.writeln('  cookbook: ${skill.cookbookFiles.join(", ")}');
          }
        }
        buf.writeln();
        buf.writeln('使用 action="read" 读取某个 Skill 的详细指令。');
        return buf.toString();

      case 'read':
        // 第2层：读取 SKILL.md 正文
        final name = args['name'] as String?;
        if (name == null) return '错误: read 需要提供 name 参数';
        final skill = registry.all.where((s) => s.name == name || s.id == name).firstOrNull;
        if (skill == null) return '错误: 找不到技能 "$name"';
        final buf = StringBuffer();
        buf.writeln('# ${skill.name}');
        buf.writeln();
        buf.writeln(skill.instructions);
        if (skill.cookbookFiles.isNotEmpty) {
          buf.writeln();
          buf.writeln('## Cookbook 文件');
          for (final f in skill.cookbookFiles) {
            buf.writeln('- $f');
          }
          buf.writeln();
          buf.writeln('使用 action="read_cookbook" 读取具体步骤文件。');
        }
        return buf.toString();

      case 'read_cookbook':
        // 第3层：读取 cookbook 详细步骤
        final name = args['name'] as String?;
        final file = args['file'] as String?;
        if (name == null) return '错误: read_cookbook 需要提供 name 参数';
        if (file == null) return '错误: read_cookbook 需要提供 file 参数';
        return await registry.getCookbookContent(
          registry.all.where((s) => s.name == name || s.id == name).firstOrNull?.id ?? name,
          file,
        );

      case 'create':
        final name = (args['name'] as String?)?.trim();
        final desc = (args['description'] as String?)?.trim();
        final instructions = (args['instructions'] as String?)?.trim();
        if (name == null || name.isEmpty) {
          return '错误: create 需要提供 name';
        }
        if (desc == null || desc.isEmpty) {
          return '错误: create 需要提供 description';
        }
        if (instructions == null || instructions.isEmpty) {
          return '错误: create 需要提供 instructions';
        }

        // 生成 skill id（小写 + 下划线）
        final skillId = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');

        // 检查是否已存在同名 Skill
        if (registry.all.any((s) => s.id == skillId)) {
          return '错误: 已存在名为 "$name" 的技能';
        }

        final keywords = (args['keywords'] as List?)
                ?.map((k) => k.toString())
                .toList() ??
            const <String>[];

        // 解析 cookbook 文件
        final cookbookMap = args['cookbook_files'] as Map<String, dynamic>?;
        final cookbookFiles = <String>[];

        final skill = Skill(
          id: skillId,
          name: name,
          description: desc,
          instructions: instructions,
          keywords: keywords,
          cookbookFiles: cookbookFiles,
        );

        registry.register(skill);
        await registry.persistSkill(skill);

        // 持久化 cookbook 文件
        if (cookbookMap != null) {
          for (final entry in cookbookMap.entries) {
            final fileName = entry.key;
            final content = entry.value.toString();
            cookbookFiles.add(fileName);
            await registry.persistCookbook(skillId, fileName, content);
          }
          // 更新内存中的 cookbookFiles 列表
          if (cookbookFiles.isNotEmpty) {
            registry.register(skill.copyWith(cookbookFiles: cookbookFiles));
          }
        }

        final buf = StringBuffer();
        buf.writeln('已创建技能「$name」');
        buf.writeln('描述: $desc');
        buf.writeln('关键词: ${keywords.isEmpty ? "无" : keywords.join("、")}');
        if (cookbookFiles.isNotEmpty) {
          buf.writeln('Cookbook: ${cookbookFiles.join(", ")}');
        }
        buf.writeln('技能已持久化，重启后仍然可用。');
        return buf.toString();

      case 'match':
        final text = args['text'] as String?;
        if (text == null) return '错误: match 需要提供 text';

        final matched = registry.matchByKeywords(text);
        if (matched.isEmpty) return '未找到匹配的 Skill';
        final buf = StringBuffer();
        for (final skill in matched) {
          buf.writeln('• ${skill.name}: ${skill.description}');
        }
        return buf.toString();

      default:
        return '错误: 未知操作类型 "$action"';
    }
  }
}
