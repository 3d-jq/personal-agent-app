import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// MCP 工具定义
class McpTool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  factory McpTool.fromJson(Map<String, dynamic> json) {
    return McpTool(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      inputSchema: json['inputSchema'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// MCP 资源定义
class McpResource {
  final String uri;
  final String name;
  final String? description;
  final String? mimeType;

  McpResource({
    required this.uri,
    required this.name,
    this.description,
    this.mimeType,
  });

  factory McpResource.fromJson(Map<String, dynamic> json) {
    return McpResource(
      uri: json['uri'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      mimeType: json['mimeType'] as String?,
    );
  }
}

/// MCP 客户端 - 连接 MCP 服务器并调用工具
///
/// 支持 Streamable HTTP 传输（MCP 规范 2025-03-26+）：
/// - 请求头声明 Accept: application/json, text/event-stream
/// - 响应可能是单个 JSON，也可能是 SSE 流（text/event-stream）
/// - 连接后必须先 initialize 握手，才能调用 tools/list 等方法
class McpClient {
  final String serverUrl;
  final String? apiKey;

  /// MCP 服务的请求路径，默认 '/'。不同服务商可能用 '/mcp' 等路径。
  final String endpoint;

  late Dio _dio;

  List<McpTool> _tools = [];
  List<McpResource> _resources = [];

  /// 当前已发现的工具列表（listTools 后填充）
  List<McpTool> get tools => List.unmodifiable(_tools);

  /// 是否已完成 initialize 握手
  bool _initialized = false;

  McpClient({
    required this.serverUrl,
    this.apiKey,
    this.endpoint = '/',
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: serverUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        // Streamable HTTP：声明客户端能处理两种响应格式
        'Accept': 'application/json, text/event-stream',
        if (apiKey != null) 'Authorization': 'Bearer $apiKey',
      },
    ));
  }

  /// JSON-RPC 请求 id 自增计数器，避免时间戳同毫秒并发时 id 冲突。
  int _rpcId = 0;

  // ═══ 连接生命周期 ═══

  /// 完整连接流程：initialize 握手 → 获取工具列表。
  ///
  /// MCP 规范要求客户端在调用任何其他方法前必须先 initialize，
  /// 协商协议版本并交换能力信息。
  Future<void> connect() async {
    await initialize();
    await listTools();
  }

  /// MCP initialize 握手。
  ///
  /// 向服务器声明客户端支持的协议版本和能力，
  /// 服务器返回其协议版本和能力。握手成功后标记为已初始化。
  Future<void> initialize() async {
    if (_initialized) return;
    // 服务器返回: {protocolVersion, capabilities, serverInfo}
    await _sendRequest('initialize', {
      'protocolVersion': '2025-03-26',
      'capabilities': {
        'roots': {'listChanged': true},
      },
      'clientInfo': {
        'name': 'DWeis-MCP-Client',
        'version': '1.0.0',
      },
    });

    _initialized = true;

    // 发送 initialized 通知（notification，无 id，不需要响应）
    try {
      await _dio.post(endpoint, data: {
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      });
    } catch (_) {
      // 通知失败不阻塞，有些服务器可能不接收通知
    }
  }

  // ═══ 工具操作 ═══

  /// 获取可用工具列表（需先 initialize）
  Future<List<McpTool>> listTools() async {
    if (!_initialized) await initialize();
    try {
      final response = await _sendRequest('tools/list', {});
      if (response['tools'] != null) {
        _tools = (response['tools'] as List)
            .map((t) => McpTool.fromJson(t as Map<String, dynamic>))
            .toList();
      }
      return _tools;
    } catch (e) {
      throw McpException('获取工具列表失败: $e');
    }
  }

  /// 获取可用资源列表
  Future<List<McpResource>> listResources() async {
    if (!_initialized) await initialize();
    try {
      final response = await _sendRequest('resources/list', {});
      if (response['resources'] != null) {
        _resources = (response['resources'] as List)
            .map((r) => McpResource.fromJson(r as Map<String, dynamic>))
            .toList();
      }
      return _resources;
    } catch (e) {
      throw McpException('获取资源列表失败: $e');
    }
  }

  /// 调用工具
  Future<Map<String, dynamic>> callTool(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    if (!_initialized) await initialize();
    try {
      final response = await _sendRequest('tools/call', {
        'name': toolName,
        'arguments': arguments,
      });
      return response;
    } catch (e) {
      throw McpException('调用工具失败: $e');
    }
  }

  /// 读取资源
  Future<Map<String, dynamic>> readResource(String uri) async {
    if (!_initialized) await initialize();
    try {
      final response = await _sendRequest('resources/read', {
        'uri': uri,
      });
      return response;
    } catch (e) {
      throw McpException('读取资源失败: $e');
    }
  }

  /// 获取提示词模板
  Future<Map<String, dynamic>> getPrompt(String promptName) async {
    if (!_initialized) await initialize();
    try {
      final response = await _sendRequest('prompts/get', {
        'name': promptName,
      });
      return response;
    } catch (e) {
      throw McpException('获取提示词失败: $e');
    }
  }

  /// 测试连接：执行完整握手（initialize → ping）
  Future<bool> testConnection() async {
    try {
      await initialize();
      await _sendRequest('ping', {});
      return true;
    } catch (e) {
      return false;
    }
  }

  // ═══ 传输层 ═══

  /// 发送 JSON-RPC 请求并解析响应。
  ///
  /// Streamable HTTP 传输下，服务器可能返回两种格式：
  /// - `application/json`：直接返回单个 JSON-RPC 响应对象
  /// - `text/event-stream`：SSE 流，需从中提取 id 匹配的 data 行
  Future<Map<String, dynamic>> _sendRequest(
    String method,
    Map<String, dynamic> params,
  ) async {
    final rpcId = ++_rpcId;
    final request = {
      'jsonrpc': '2.0',
      'id': rpcId,
      'method': method,
      'params': params,
    };

    final response = await _dio.post(endpoint, data: request);
    final contentType =
        (response.headers.value('content-type') ?? '').toLowerCase();

    Map<String, dynamic>? data;

    if (contentType.contains('text/event-stream')) {
      // SSE 流式响应：从 data: 行中提取 JSON-RPC 响应
      data = _parseSseResponse(response.data, rpcId);
    } else if (response.data is Map<String, dynamic>) {
      // 普通 JSON 响应
      data = response.data as Map<String, dynamic>;
    } else if (response.data is String) {
      // 有些服务器返回 text/plain 但内容是 JSON
      data = _tryParseJsonString(response.data as String);
    }

    if (data == null) {
      throw McpException('无效的响应格式: $contentType');
    }

    if (data.containsKey('error')) {
      final error = data['error'] as Map<String, dynamic>;
      throw McpException(error['message'] as String? ?? '未知错误');
    }

    return data['result'] as Map<String, dynamic>? ?? {};
  }

  /// 从 SSE 流响应中提取匹配指定 id 的 JSON-RPC 响应。
  ///
  /// SSE 格式：
  /// ```
  /// event: message
  /// data: {"jsonrpc":"2.0","id":1,"result":{...}}
  /// ```
  Map<String, dynamic>? _parseSseResponse(dynamic body, int rpcId) {
    final text = body is String ? body : body.toString();
    final lines = text.split('\n');
    final buf = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('data:')) {
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        buf.write(payload);
        // 尝试解析累积的 data 内容
        final parsed = _tryParseJsonString(buf.toString());
        if (parsed != null) {
          buf.clear();
          final id = parsed['id'];
          if (id == rpcId) {
            return parsed;
          }
          // 也可能是 notification（无 id），跳过
        }
      } else if (line.trim().isEmpty) {
        // 事件分隔，清空缓冲
        buf.clear();
      }
    }

    return null;
  }

  /// 尝试解析 JSON 字符串，失败返回 null
  Map<String, dynamic>? _tryParseJsonString(String s) {
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  /// 获取所有工具的函数定义（用于 AI 模型）
  List<Map<String, dynamic>> getToolDefinitions() {
    return _tools.map((tool) {
      return {
        'name': tool.name,
        'description': tool.description,
        'inputSchema': tool.inputSchema,
      };
    }).toList();
  }
}

/// MCP 异常
class McpException implements Exception {
  final String message;
  McpException(this.message);

  @override
  String toString() => 'McpException: $message';
}
