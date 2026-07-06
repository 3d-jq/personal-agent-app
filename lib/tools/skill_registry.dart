import '../models/skill.dart';

/// 技能注册表
///
/// 管理所有已发现和已激活的 Skill
class SkillRegistry {
  SkillRegistry();

  final Map<String, Skill> _skills = {};
  final Set<String> _activeSkillIds = {};

  /// 注册 Skill
  void register(Skill skill) {
    _skills[skill.id] = skill;
  }

  /// 注册内置 Skill
  void registerBuiltInSkills() {
    // create-skill: 让大模型在对话中创建自定义 Skill
    register(Skill(
      id: 'create-skill',
      name: 'create-skill',
      description: '创建自定义 Skill。当用户想要创建新的 Skill 时使用此工具。',
      instructions: '''当用户想要创建新的 Skill 时：

1. 询问用户 Skill 的名称和描述
2. 询问 Skill 的触发关键词
3. 询问 Skill 的指令内容（AI 在什么情况下使用这个 Skill）
4. 使用 skill_manage 工具注册新的 Skill
5. 告诉用户 Skill 已创建并启用

创建 Skill 时，指令应该清晰描述：
- 什么情况下激活这个 Skill
- Skill 需要执行什么步骤
- 使用哪些工具''',
      keywords: ['创建skill', '新建skill', '自定义skill', '添加skill'],
    ));
  }

  /// 获取所有已注册 Skill
  List<Skill> get all => List.unmodifiable(_skills.values);

  /// 获取所有已激活的 Skill
  List<Skill> get active =>
      _skills.values.where((s) => _activeSkillIds.contains(s.id)).toList();

  /// 激活 Skill
  void activate(String skillId) {
    _activeSkillIds.add(skillId);
  }

  /// 停用 Skill
  void deactivate(String skillId) {
    _activeSkillIds.remove(skillId);
  }

  /// 检查 Skill 是否已激活
  bool isActive(String skillId) => _activeSkillIds.contains(skillId);

  /// 根据关键词匹配可能需要的 Skill
  List<Skill> matchByKeywords(String text) {
    final lower = text.toLowerCase();
    return _skills.values.where((s) {
      return s.keywords.any((kw) => lower.contains(kw.toLowerCase()));
    }).toList();
  }

  /// 获取激活 Skill 的指令内容
  String getActiveInstructions() {
    final buf = StringBuffer();
    for (final skill in active) {
      if (skill.instructions.isNotEmpty) {
        buf.writeln('<skill name="${skill.name}">');
        buf.writeln(skill.instructions);
        buf.writeln('</skill>');
        buf.writeln();
      }
    }
    return buf.toString();
  }

  /// 获取 Skill 目录（用于注入到 system prompt）
  String getCatalog() {
    if (_skills.isEmpty) return '';
    
    final buf = StringBuffer();
    buf.writeln('<available_skills>');
    for (final skill in _skills.values) {
      buf.writeln('  <skill>');
      buf.writeln('    <name>${skill.name}</name>');
      buf.writeln('    <description>${skill.description}</description>');
      if (skill.location.isNotEmpty) {
        buf.writeln('    <location>${skill.location}</location>');
      }
      buf.writeln('  </skill>');
    }
    buf.writeln('</available_skills>');
    return buf.toString();
  }
}
