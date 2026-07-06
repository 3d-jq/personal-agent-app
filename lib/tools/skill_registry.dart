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

  /// 获取激活 Skill 包含的工具名
  List<String> getActiveToolNames() {
    final names = <String>[];
    for (final skill in active) {
      names.addAll(skill.resourcePaths);
    }
    return names;
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
