import '../models/chat_message.dart';

class ChatSession {
  String id;
  String title;
  List<ChatMessage> messages;
  DateTime createdAt;
  DateTime updatedAt;
  String type; // 'chat' = 单聊, 'agent' = Agent 单聊

  ChatSession({
    required this.id,
    this.title = '新对话',
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.type = 'chat',
  }) : messages = messages ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'type': type,
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? '新对话',
      messages:
          (json['messages'] as List?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] as int? ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        json['updatedAt'] as int? ?? 0,
      ),
      type: json['type'] as String? ?? 'chat',
    );
  }
}
