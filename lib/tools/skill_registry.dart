import 'base_tool.dart';
import 'tool_registry.dart';

/// Agent 技能包：一组相关工具 + prompt 模板 + 使用说明
class Skill {
  final String id;
  final String name;
  final String description;
  final List<String> toolNames; // 该技能包含的工具名
  final String promptTemplate; // 注入到 system prompt 的模板
  final List<String> keywords; // 触发关键词

  const Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.toolNames,
    this.promptTemplate = '',
    this.keywords = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'toolNames': toolNames,
    'promptTemplate': promptTemplate,
    'keywords': keywords,
  };

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    toolNames: (json['toolNames'] as List).cast<String>(),
    promptTemplate: json['promptTemplate'] as String? ?? '',
    keywords: (json['keywords'] as List?)?.cast<String>() ?? [],
  );
}

/// 技能注册表
class SkillRegistry {
  SkillRegistry();

  final List<Skill> _skills = [];
  final Set<String> _activeSkillIds = {};

  /// 注册技能
  void register(Skill skill) {
    _skills.add(skill);
  }

  /// 获取所有已注册技能
  List<Skill> get all => List.unmodifiable(_skills);

  /// 获取所有已激活的技能
  List<Skill> get active =>
      _skills.where((s) => _activeSkillIds.contains(s.id)).toList();

  /// 激活技能
  void activate(String skillId) {
    _activeSkillIds.add(skillId);
  }

  /// 停用技能
  void deactivate(String skillId) {
    _activeSkillIds.remove(skillId);
  }

  /// 检查技能是否已激活
  bool isActive(String skillId) => _activeSkillIds.contains(skillId);

  /// 根据关键词匹配可能需要的技能
  List<Skill> matchByKeywords(String text) {
    final lower = text.toLowerCase();
    return _skills.where((s) {
      return s.keywords.any((kw) => lower.contains(kw.toLowerCase()));
    }).toList();
  }

  /// 获取激活技能的 prompt 片段
  String getActivePrompts() {
    final buf = StringBuffer();
    for (final skill in active) {
      if (skill.promptTemplate.isNotEmpty) {
        buf.writeln(skill.promptTemplate);
        buf.writeln();
      }
    }
    return buf.toString();
  }

  /// 获取激活技能包含的工具名
  List<String> getActiveToolNames() {
    final names = <String>[];
    for (final skill in active) {
      names.addAll(skill.toolNames);
    }
    return names;
  }

  /// 列出所有技能（用于 tool_search）
  String listAll() {
    if (_skills.isEmpty) return '没有已注册的技能。';
    final buf = StringBuffer('【已注册技能】\n');
    for (final s in _skills) {
      final status = isActive(s.id) ? '✅ 已激活' : '⬜ 未激活';
      buf.writeln('${s.id}: ${s.name} — $status');
      buf.writeln('  ${s.description}');
      buf.writeln('  包含工具: ${s.toolNames.join(", ")}');
      buf.writeln();
    }
    return buf.toString();
  }
}

/// 预置技能定义
class BuiltInSkills {
  BuiltInSkills._();

  static final List<Skill> all = [
    Skill(
      id: 'data_analysis',
      name: '数据分析',
      description: '搜索数据、整理分析、生成报告',
      toolNames: ['searxng_search', 'tavily_search', 'web_fetch', 'save_note'],
      promptTemplate:
          '## 数据分析技能已激活\n'
          '当用户需要数据分析时，按以下流程执行：\n'
          '1. 用搜索工具收集数据\n'
          '2. 用 web_fetch 获取详细内容\n'
          '3. 整理分析结果\n'
          '4. 用 save_note 保存报告',
      keywords: ['分析', '数据', '报告', '统计', '趋势', '对比'],
    ),
    Skill(
      id: 'content_creation',
      name: '内容创作',
      description: '写作、笔记、图文创作',
      toolNames: ['save_note', 'create_rich_note', 'generate_image'],
      promptTemplate:
          '## 内容创作技能已激活\n'
          '当用户需要创作内容时：\n'
          '1. 理解用户需求和风格偏好\n'
          '2. 草拟内容\n'
          '3. 用 save_note 或 create_rich_note 保存',
      keywords: ['写作', '文章', '笔记', '创作', '文案', '摘要'],
    ),
    Skill(
      id: 'media_generation',
      name: '媒体生成',
      description: '生成图片和视频',
      toolNames: ['generate_image', 'generate_video'],
      promptTemplate:
          '## 媒体生成技能已激活\n'
          '当用户需要生成图片或视频时：\n'
          '1. 确认用户需求（风格、内容、尺寸）\n'
          '2. 构造合适的 prompt\n'
          '3. 调用生成工具\n'
          '4. 展示结果并询问是否需要调整',
      keywords: ['图片', '视频', '生成', '画', '绘', '照片', '动画'],
    ),
    Skill(
      id: 'knowledge_research',
      name: '知识研究',
      description: '深度搜索、知识库查阅、学习整理',
      toolNames: [
        'searxng_search',
        'tavily_search',
        'web_fetch',
        'context_doc',
        'save_note',
      ],
      promptTemplate:
          '## 知识研究技能已激活\n'
          '当用户需要深度研究某个话题时：\n'
          '1. 先查阅知识库（context_doc）\n'
          '2. 用搜索工具补充最新信息\n'
          '3. 用 web_fetch 获取详细内容\n'
          '4. 整理成结构化笔记',
      keywords: ['研究', '学习', '了解', '深入', '知识', '学习'],
    ),
    Skill(
      id: 'life_planning',
      name: '生活规划',
      description: '日程管理、提醒设置、生活建议',
      toolNames: ['reminder', 'calendar', 'location', 'weather'],
      promptTemplate:
          '## 生活规划技能已激活\n'
          '当用户需要生活规划相关帮助时：\n'
          '1. 获取当前位置和天气\n'
          '2. 查询日历安排\n'
          '3. 设置提醒\n'
          '4. 提供个性化建议',
      keywords: ['日程', '提醒', '计划', '安排', '天气', '出行'],
    ),
  ];
}
