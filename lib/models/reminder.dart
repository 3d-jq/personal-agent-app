class Reminder {
  final String id;
  final String title;
  final String message;
  final DateTime scheduledTime;
  bool isCompleted;
  final DateTime createdAt;

  Reminder({
    required this.id,
    required this.title,
    required this.message,
    required this.scheduledTime,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'scheduledTime': scheduledTime.toIso8601String(),
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        scheduledTime: DateTime.tryParse(json['scheduledTime'] as String? ?? '') ?? DateTime.now(),
        isCompleted: json['isCompleted'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  bool get isPending => !isCompleted && scheduledTime.isAfter(DateTime.now());
  bool get isExpired => !isCompleted && scheduledTime.isBefore(DateTime.now());
}
