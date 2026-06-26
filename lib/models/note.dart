class Note {
  final String id;
  String title;
  String content;
  final DateTime createdAt;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> json) {
    String asText(Object? value, String fallback) {
      if (value == null) return fallback;
      if (value is String) return value;
      return value.toString();
    }

    return Note(
      id: asText(json['id'], DateTime.now().millisecondsSinceEpoch.toString()),
      title: asText(json['title'], ''),
      content: asText(json['content'], ''),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String get summary {
    final plain = content
        .replaceAll(RegExp(r'[#*_`>\-]'), '')
        .replaceAll('\n', ' ')
        .trim();
    return plain.length > 80 ? '${plain.substring(0, 80)}…' : plain;
  }
}
