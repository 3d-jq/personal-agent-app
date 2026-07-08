/// MCP 配置数据模型
class McpServer {
  final String id;
  final String name;
  final String url;
  final String? apiKey;
  final bool isEnabled;

  /// MCP 服务的请求路径，默认 '/'。有些服务商用 '/mcp'。
  final String endpoint;

  /// 附加到每个请求的 URL query 参数。
  /// 例如高德地图 MCP 需要通过 `?key=xxx` 传递 API Key。
  final Map<String, String> queryParams;

  McpServer({
    required this.id,
    required this.name,
    required this.url,
    this.apiKey,
    this.isEnabled = true,
    this.endpoint = '/',
    Map<String, String>? queryParams,
  }) : queryParams = queryParams ?? const {};

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'apiKey': apiKey,
    'isEnabled': isEnabled,
    'endpoint': endpoint,
    'queryParams': queryParams,
  };

  factory McpServer.fromJson(Map<String, dynamic> json) => McpServer(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    apiKey: json['apiKey'] as String?,
    isEnabled: json['isEnabled'] as bool? ?? true,
    endpoint: json['endpoint'] as String? ?? '/',
    queryParams: (json['queryParams'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as String)),
  );

  McpServer copyWith({
    String? name,
    String? url,
    String? apiKey,
    bool? isEnabled,
    String? endpoint,
    Map<String, String>? queryParams,
  }) => McpServer(
    id: id,
    name: name ?? this.name,
    url: url ?? this.url,
    apiKey: apiKey ?? this.apiKey,
    isEnabled: isEnabled ?? this.isEnabled,
    endpoint: endpoint ?? this.endpoint,
    queryParams: queryParams ?? this.queryParams,
  );
}
