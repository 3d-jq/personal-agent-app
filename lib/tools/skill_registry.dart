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
    // 数据分析 Skill
    register(Skill(
      id: 'data_analysis',
      name: '数据分析',
      description: '搜索数据、整理分析、生成图表和报告',
      instructions: '当用户需要分析数据时：\n1. 使用搜索工具获取相关数据\n2. 整理和清洗数据\n3. 生成可视化图表\n4. 提供分析报告',
      keywords: ['分析', '数据', '图表', '报告', '统计'],
    ));

    // 内容创作 Skill
    register(Skill(
      id: 'content_creation',
      name: '内容创作',
      description: '写作、笔记、图文创作',
      instructions: '当用户需要创作内容时：\n1. 了解用户需求和目标受众\n2. 构思内容结构\n3. 撰写初稿\n4. 润色和优化',
      keywords: ['写作', '文章', '文案', '笔记', '创作'],
    ));

    // 媒体生成 Skill
    register(Skill(
      id: 'media_generation',
      name: '媒体生成',
      description: '生成图片和视频',
      instructions: '当用户需要生成媒体内容时：\n1. 理解用户需求\n2. 使用图片/视频生成工具\n3. 提供生成的内容',
      keywords: ['图片', '视频', '生成', '创作', '设计'],
    ));

    // 知识研究 Skill
    register(Skill(
      id: 'knowledge_research',
      name: '知识研究',
      description: '深度搜索、知识库查阅、信息整理',
      instructions: '当用户需要研究知识时：\n1. 使用搜索工具获取相关信息\n2. 整理和归纳信息\n3. 提供结构化的研究报告',
      keywords: ['研究', '搜索', '知识', '学习', '资料'],
    ));

    // 生活规划 Skill
    register(Skill(
      id: 'life_planning',
      name: '生活规划',
      description: '日程管理、提醒设置、生活建议',
      instructions: '当用户需要生活规划时：\n1. 了解用户需求\n2. 制定计划\n3. 设置提醒\n4. 提供执行建议',
      keywords: ['计划', '日程', '提醒', '安排', '规划'],
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
