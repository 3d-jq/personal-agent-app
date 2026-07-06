/// 标准 Skill 数据模型
///
/// 每个 Skill 对应一个文件夹，包含：
/// - SKILL.md（元数据 + 指令）
/// - 可选的资源文件（脚本、参考文档等）
class Skill {
  final String id;
  final String name;
  final String description;
  final String instructions; // SKILL.md 正文内容
  final List<String> keywords; // 触发关键词
  final List<String> resourcePaths; // 资源文件路径
  final String location; // SKILL.md 文件路径

  const Skill({
    required this.id,
    required this.name,
    required this.description,
    this.instructions = '',
    this.keywords = const [],
    this.resourcePaths = const [],
    this.location = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'instructions': instructions,
    'keywords': keywords,
    'resourcePaths': resourcePaths,
    'location': location,
  };

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    instructions: json['instructions'] as String? ?? '',
    keywords: (json['keywords'] as List?)?.cast<String>() ?? [],
    resourcePaths: (json['resourcePaths'] as List?)?.cast<String>() ?? [],
    location: json['location'] as String? ?? '',
  );

  /// 从 SKILL.md 文件解析 Skill
  factory Skill.fromMarkdown(String name, String content, {String location = ''}) {
    // 解析 frontmatter
    final frontmatterRegex = RegExp(r'^---\s*\n(.*?)\n---\s*\n', dotAll: true);
    final match = frontmatterRegex.firstMatch(content);
    
    String description = '';
    String instructions = '';
    List<String> keywords = [];

    if (match != null) {
      final frontmatter = match.group(1) ?? '';
      instructions = content.substring(match.end).trim();
      
      // 简单解析 YAML frontmatter
      for (final line in frontmatter.split('\n')) {
        if (line.startsWith('description:')) {
          description = line.substring('description:'.length).trim();
        } else if (line.startsWith('keywords:')) {
          final keywordsStr = line.substring('keywords:'.length).trim();
          keywords = keywordsStr.split(',').map((s) => s.trim()).toList();
        }
      }
    } else {
      instructions = content.trim();
    }

    return Skill(
      id: name,
      name: name,
      description: description,
      instructions: instructions,
      keywords: keywords,
      location: location,
    );
  }
}
