/// AI 厂商配置数据模型
class VendorConfig {
  final String id;
  final String name;
  final String apiKey;
  final String baseUrl;
  final String model;
  final bool isBuiltIn;
  
  VendorConfig({
    required this.id,
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    this.model = '',
    this.isBuiltIn = false,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'isBuiltIn': isBuiltIn,
  };
  
  factory VendorConfig.fromJson(Map<String, dynamic> j) => VendorConfig(
    id: j['id'] as String,
    name: j['name'] as String,
    apiKey: j['apiKey'] as String? ?? '',
    baseUrl: j['baseUrl'] as String? ?? '',
    model: j['model'] as String? ?? '',
    isBuiltIn: j['isBuiltIn'] as bool? ?? false,
  );
  
  VendorConfig copyWith({
    String? name,
    String? apiKey,
    String? baseUrl,
    String? model,
  }) => VendorConfig(
    id: id,
    name: name ?? this.name,
    apiKey: apiKey ?? this.apiKey,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    isBuiltIn: isBuiltIn,
  );
}
