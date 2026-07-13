/// AI 厂商配置数据模型
///
/// [protocol] 显式声明该厂商走哪种接口协议：
/// - `'openai'`   : OpenAI Chat Completions 兼容格式（含 DeepSeek / 通义 / Ollama / vLLM 等绝大多数厂商）
/// - `'anthropic'`: Anthropic Messages API 格式
/// 旧数据未含此字段时默认 `'openai'`。
class VendorConfig {
  final String id;
  final String name;
  final String apiKey;
  final String baseUrl;
  final String model;
  final bool isBuiltIn;
  final String protocol;

  VendorConfig({
    required this.id,
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    this.model = '',
    this.isBuiltIn = false,
    this.protocol = 'openai',
  });

  /// 该厂商是否为 Anthropic 协议
  bool get isAnthropic => protocol == 'anthropic';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'model': model,
    'isBuiltIn': isBuiltIn,
    'protocol': protocol,
    // apiKey 不在 JSON 中，走 flutter_secure_storage 加密存储
  };

  factory VendorConfig.fromJson(Map<String, dynamic> j) => VendorConfig(
    id: j['id'] as String,
    name: j['name'] as String,
    apiKey: j['apiKey'] as String? ?? '', // 迁移用：旧数据含明文 key
    baseUrl: j['baseUrl'] as String? ?? '',
    model: j['model'] as String? ?? '',
    isBuiltIn: j['isBuiltIn'] as bool? ?? false,
    protocol: j['protocol'] as String? ?? 'openai',
  );

  VendorConfig copyWith({
    String? name,
    String? apiKey,
    String? baseUrl,
    String? model,
    String? protocol,
  }) => VendorConfig(
    id: id,
    name: name ?? this.name,
    apiKey: apiKey ?? this.apiKey,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    isBuiltIn: isBuiltIn,
    protocol: protocol ?? this.protocol,
  );
}
