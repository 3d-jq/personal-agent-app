enum MediaType { image, video }

class MediaItem {
  final String id;
  final MediaType type;
  final String filePath;
  final String prompt;
  final DateTime createdAt;

  MediaItem({
    required this.id,
    required this.type,
    required this.filePath,
    required this.prompt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'filePath': filePath,
        'prompt': prompt,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'] as String,
        type: MediaType.values.firstWhere((e) => e.name == json['type'], orElse: () => MediaType.image),
        filePath: json['filePath'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
