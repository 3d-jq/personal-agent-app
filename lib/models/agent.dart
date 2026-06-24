import '../services/ai_service.dart';
import '../tools/base_tool.dart';

/// 一个 Agent 定义：角色 + 性格 + 工具 + 模型
class Agent {
  final String id;
  String name; // 群内 @ 用的名字（精确匹配）
  String role; // 一句话职能描述
  String avatar; // emoji 或空字符串（前端回退到色块）
  String systemPrompt;
  String vendorId; // 引用 AISettings.vendors 中的 vendor id
  String model; // 模型名（vendor.model 或自定义）
  List<String> allowedToolNames; // 工具白名单（来自 base_tool.name）
  bool isCoordinator; // 是否是协调者（常驻响应、可 @ 所有人）

  Agent({
    required this.id,
    required this.name,
    this.role = '',
    this.avatar = '',
    this.systemPrompt = '',
    this.vendorId = '',
    this.model = '',
    List<String>? allowedToolNames,
    this.isCoordinator = false,
  }) : allowedToolNames = allowedToolNames ?? const [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'avatar': avatar,
    'systemPrompt': systemPrompt,
    'vendorId': vendorId,
    'model': model,
    'allowedToolNames': allowedToolNames,
    'isCoordinator': isCoordinator,
  };

  factory Agent.fromJson(Map<String, dynamic> j) => Agent(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    role: j['role'] as String? ?? '',
    avatar: j['avatar'] as String? ?? '',
    systemPrompt: j['systemPrompt'] as String? ?? '',
    vendorId: j['vendorId'] as String? ?? '',
    model: j['model'] as String? ?? '',
    allowedToolNames:
        (j['allowedToolNames'] as List?)?.cast<String>() ?? const [],
    isCoordinator: j['isCoordinator'] as bool? ?? false,
  );

  Agent copyWith({
    String? name,
    String? role,
    String? avatar,
    String? systemPrompt,
    String? vendorId,
    String? model,
    List<String>? allowedToolNames,
    bool? isCoordinator,
  }) => Agent(
    id: id,
    name: name ?? this.name,
    role: role ?? this.role,
    avatar: avatar ?? this.avatar,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    vendorId: vendorId ?? this.vendorId,
    model: model ?? this.model,
    allowedToolNames: allowedToolNames ?? this.allowedToolNames,
    isCoordinator: isCoordinator ?? this.isCoordinator,
  );
}
