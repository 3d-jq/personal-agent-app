/// 标准 Skill 数据模型（Agent Skills Open Standard）
///
/// 采用渐进式披露架构：
/// - 第1层 frontmatter（始终加载）：name + description + keywords
/// - 第2层 SKILL.md 正文（按需读取）：概述 + 路由表
/// - 第3层 cookbook/*.md（按需读取）：详细操作步骤
///
/// 存储格式为目录：
/// ```
/// skills/{name}/
///   ├── SKILL.md          # frontmatter + 正文
///   └── cookbook/          # 可选，详细步骤
///       ├── order.md
///       └── query.md
/// ```
class Skill {
  final String id;
  final String name;
  final String description;
  final String instructions; // SKILL.md 正文（frontmatter 之后的内容）
  final List<String> keywords;
  final List<String> cookbookFiles; // cookbook/ 下的文件名列表
  final String location; // SKILL.md 文件路径

  const Skill({
    required this.id,
    required this.name,
    required this.description,
    this.instructions = '',
    this.keywords = const [],
    this.cookbookFiles = const [],
    this.location = '',
  });

  Skill copyWith({
    String? name,
    String? description,
    String? instructions,
    List<String>? keywords,
    List<String>? cookbookFiles,
    String? location,
  }) => Skill(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    instructions: instructions ?? this.instructions,
    keywords: keywords ?? this.keywords,
    cookbookFiles: cookbookFiles ?? this.cookbookFiles,
    location: location ?? this.location,
  );

  /// 序列化为 JSON（用于旧格式兼容/内存操作）
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'instructions': instructions,
    'keywords': keywords,
    'cookbookFiles': cookbookFiles,
    'location': location,
  };

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    instructions: json['instructions'] as String? ?? '',
    keywords: (json['keywords'] as List?)?.cast<String>() ?? [],
    cookbookFiles: (json['cookbookFiles'] as List?)?.cast<String>() ?? [],
    location: json['location'] as String? ?? '',
  );

  /// 从 SKILL.md 文件内容解析 Skill（只解析 frontmatter + 正文，不读 cookbook）
  factory Skill.fromMarkdown(String name, String content, {String location = ''}) {
    String description = '';
    String instructions = '';
    List<String> keywords = [];

    final frontmatterRegex = RegExp(r'^---\s*\n(.*?)\n---\s*\n', dotAll: true);
    final match = frontmatterRegex.firstMatch(content);

    if (match != null) {
      final frontmatter = match.group(1) ?? '';
      instructions = content.substring(match.end).trim();

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

  /// 序列化为 SKILL.md 文件内容（frontmatter + 正文）
  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('---');
    buf.writeln('name: $name');
    buf.writeln('description: $description');
    if (keywords.isNotEmpty) {
      buf.writeln('keywords: ${keywords.join(',')}');
    }
    buf.writeln('---');
    buf.writeln();
    buf.write(instructions);
    return buf.toString();
  }
}
