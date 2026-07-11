import '../models/chat_message.dart';

class ChatSession {
  String id;
  String title;
  List<ChatMessage> messages;
  DateTime createdAt;
  DateTime updatedAt;
  String type; // 'chat' = 单聊, 'agent' = Agent 单聊

  /// 列表页轻量展示用：最后一条消息的文本摘要（不加载完整消息体）。
  String? preview;
  /// 列表页轻量展示用：消息总数（来自 messages 表，避免反序列化整包历史）。
  int messageCount;

  ChatSession({
    required this.id,
    this.title = '新对话',
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.type = 'chat',
    this.preview,
    this.messageCount = 0,
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
    if (preview != null) 'preview': preview,
    'messageCount': messageCount,
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
      preview: json['preview'] as String?,
      messageCount: json['messageCount'] as int? ?? 0,
    );
  }
}
