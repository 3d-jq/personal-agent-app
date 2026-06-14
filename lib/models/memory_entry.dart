import 'dart:convert';

enum MemoryType { fact, preference }

class MemoryEntry {
  String id;
  final MemoryType type;
  String content;
  final DateTime createdAt;

  MemoryEntry({
    required this.id,
    required this.type,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'content': content,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory MemoryEntry.fromJson(Map<String, dynamic> j) => MemoryEntry(
    id: j['id'] as String,
    type: MemoryType.values.firstWhere((e) => e.name == (j['type'] as String)),
    content: j['content'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int? ?? 0),
  );
}
