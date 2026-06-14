import 'chat_message.dart';

/// Agent 群：常驻的多 Agent 讨论容器
class AgentGroup {
  String id;
  String name;
  String description;
  List<String> agentIds;       // 群内 Agent 成员
  List<ChatMessage> messages;  // 复用 ChatMessage（含 mentions）
  DateTime createdAt;
  DateTime updatedAt;

  AgentGroup({
    required this.id,
    this.name = '新群',
    this.description = '',
    List<String>? agentIds,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : agentIds = agentIds ?? [],
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'agentIds': agentIds,
        'messages': messages
            .map((m) => {
                  'text': m.text,
                  'isUser': m.isUser,
                  'speakerId': m.speakerId, // Agent 发言时填 agent.id；用户为 null
                  'mentions': m.mentions,
                })
            .toList(),
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory AgentGroup.fromJson(Map<String, dynamic> j) => AgentGroup(
        id: j['id'] as String,
        name: j['name'] as String? ?? '新群',
        description: j['description'] as String? ?? '',
        agentIds: (j['agentIds'] as List?)?.cast<String>() ?? [],
        messages: (j['messages'] as List?)
                ?.map((m) => ChatMessage(
                      text: (m as Map)['text'] as String? ?? '',
                      isUser: m['isUser'] as bool? ?? false,
                      speakerId: m['speakerId'] as String?,
                      mentions: (m['mentions'] as List?)?.cast<String>() ??
                          const [],
                    ))
                .toList() ??
            [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            j['createdAt'] as int? ?? 0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            j['updatedAt'] as int? ?? 0),
      );
}
