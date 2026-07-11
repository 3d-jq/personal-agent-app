import '../core/service_locator.dart';
import '../models/skill.dart';
import 'base_tool.dart';
import 'skill_registry.dart';
import 'skill_list_tool.g.dart';
import 'skill_read_tool.g.dart';
import 'skill_read_cookbook_tool.g.dart';
import 'skill_create_tool.g.dart';
import 'skill_match_tool.g.dart';

/// 技能管理工具：让 Agent 查看、创建和读取技能包。
///
/// 原 `skill_manage`（带 action 参数）已拆分为 5 个独立工具，各自独占调用配额：
/// - [SkillListTool]       列出所有 Skill（name + description）
/// - [SkillReadTool]       读取 Skill 正文（SKILL.md 内容）
/// - [SkillReadCookbookTool] 读取 cookbook 详细步骤文件
/// - [SkillCreateTool]     创建新技能
/// - [SkillMatchTool]      关键词匹配技能
///
/// 采用渐进式披露：先 list 看目录，再 read 读正文，再 read_cookbook 读步骤。
abstract class _SkillManageBase extends AgentTool {
  @override
  bool get readOnly => false;

  SkillRegistry get _registry => getIt<SkillRegistry>();

  String list() {
    final skills = _registry.all;
    if (skills.isEmpty) return '暂无可用 Skill';
    final buf = StringBuffer();
    for (final skill in skills) {
      buf.writeln('• ${skill.name}: ${skill.description}');
      if (skill.cookbookFiles.isNotEmpty) {
        buf.writeln('  cookbook: ${skill.cookbookFiles.join(", ")}');
      }
    }
    buf.writeln();
    buf.writeln('使用 skill_read 读取某个 Skill 的详细指令。');
    return buf.toString();
  }

  String read(Map<String, dynamic> args) {
    final name = args['name'] as String?;
    if (name == null) return '错误: read 需要提供 name 参数';
    final skill = _registry.all.where((s) => s.name == name || s.id == name).firstOrNull;
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
      buf.writeln('使用 skill_read_cookbook 读取具体步骤文件。');
    }
    return buf.toString();
  }

  Future<String> readCookbook(Map<String, dynamic> args) async {
    final name = args['name'] as String?;
    final file = args['file'] as String?;
    if (name == null) return '错误: read_cookbook 需要提供 name 参数';
    if (file == null) return '错误: read_cookbook 需要提供 file 参数';
    return await _registry.getCookbookContent(
      _registry.all.where((s) => s.name == name || s.id == name).firstOrNull?.id ?? name,
      file,
    );
  }

  Future<String> create(Map<String, dynamic> args) async {
    final name = (args['name'] as String?)?.trim();
    final desc = (args['description'] as String?)?.trim();
    final instructions = (args['instructions'] as String?)?.trim();
    if (name == null || name.isEmpty) return '错误: create 需要提供 name';
    if (desc == null || desc.isEmpty) return '错误: create 需要提供 description';
    if (instructions == null || instructions.isEmpty) {
      return '错误: create 需要提供 instructions';
    }

    final skillId = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    if (_registry.all.any((s) => s.id == skillId)) {
      return '错误: 已存在名为 "$name" 的技能';
    }

    final keywords = (args['keywords'] as List?)
            ?.map((k) => k.toString())
            .toList() ??
        const <String>[];

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

    _registry.register(skill);
    await _registry.persistSkill(skill);

    if (cookbookMap != null) {
      for (final entry in cookbookMap.entries) {
        final fileName = entry.key;
        final content = entry.value.toString();
        cookbookFiles.add(fileName);
        await _registry.persistCookbook(skillId, fileName, content);
      }
      if (cookbookFiles.isNotEmpty) {
        _registry.register(skill.copyWith(cookbookFiles: cookbookFiles));
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
  }

  String match(Map<String, dynamic> args) {
    final text = args['text'] as String?;
    if (text == null) return '错误: match 需要提供 text';
    final matched = _registry.matchByKeywords(text);
    if (matched.isEmpty) return '未找到匹配的 Skill';
    final buf = StringBuffer();
    for (final skill in matched) {
      buf.writeln('• ${skill.name}: ${skill.description}');
    }
    return buf.toString();
  }
}

/// 列出所有可用 Skill（name + description）。
class SkillListTool extends _SkillManageBase {
  @override
  String get name => 'skill_list';
  @override
  String get description => skillListToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': <String, dynamic>{},
    'required': <String>[],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async => list();
}

/// 读取某个 Skill 的正文指令（SKILL.md 内容）。
class SkillReadTool extends _SkillManageBase {
  @override
  String get name => 'skill_read';
  @override
  String get description => skillReadToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': '技能名称'},
    },
    'required': ['name'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async => read(args);
}

/// 读取某个 Skill 的 cookbook 详细步骤文件。
class SkillReadCookbookTool extends _SkillManageBase {
  @override
  String get name => 'skill_read_cookbook';
  @override
  String get description => skillReadCookbookToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': '技能名称'},
      'file': {'type': 'string', 'description': 'cookbook 文件名'},
    },
    'required': ['name', 'file'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async => readCookbook(args);
}

/// 创建新技能（含正文、关键词、cookbook 文件）。
class SkillCreateTool extends _SkillManageBase {
  @override
  String get name => 'skill_create';
  @override
  String get description => skillCreateToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': '技能名称'},
      'description': {
        'type': 'string',
        'description': '技能描述，应包含触发场景说明',
      },
      'instructions': {
        'type': 'string',
        'description': '技能指令正文：什么情况下使用、执行什么步骤、用哪些工具',
      },
      'keywords': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': '触发关键词列表（可选）',
      },
      'cookbook_files': {
        'type': 'object',
        'description': 'cookbook 文件映射（可选），key=文件名 value=文件内容',
      },
    },
    'required': ['name', 'description', 'instructions'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async => create(args);
}

/// 按关键词匹配最相关的 Skill。
class SkillMatchTool extends _SkillManageBase {
  @override
  String get name => 'skill_match';
  @override
  String get description => skillMatchToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'text': {'type': 'string', 'description': '用户输入文本'},
    },
    'required': ['text'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async => match(args);
}
