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
class McpClient {
  final String serverUrl;
  final String? apiKey;
  late Dio _dio;

  List<McpTool> _tools = [];
  List<McpResource> _resources = [];

  McpClient({
    required this.serverUrl,
    this.apiKey,
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: serverUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        if (apiKey != null) 'Authorization': 'Bearer $apiKey',
      },
    ));
  }

  /// 获取可用工具列表
  Future<List<McpTool>> listTools() async {
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
    try {
      final response = await _sendRequest('prompts/get', {
        'name': promptName,
      });
      return response;
    } catch (e) {
      throw McpException('获取提示词失败: $e');
    }
  }

  /// 测试连接
  Future<bool> testConnection() async {
    try {
      await _sendRequest('ping', {});
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 发送 JSON-RPC 请求
  Future<Map<String, dynamic>> _sendRequest(
    String method,
    Map<String, dynamic> params,
  ) async {
    final request = {
      'jsonrpc': '2.0',
      'id': DateTime.now().millisecondsSinceEpoch,
      'method': method,
      'params': params,
    };

    final response = await _dio.post('/', data: request);

    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('error')) {
        final error = data['error'] as Map<String, dynamic>;
        throw McpException(error['message'] as String? ?? '未知错误');
      }
      return data['result'] as Map<String, dynamic>? ?? {};
    }

    throw McpException('无效的响应格式');
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
