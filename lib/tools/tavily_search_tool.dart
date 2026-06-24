import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/crypto_util.dart';
import '../tools/base_tool.dart';
import 'tavily_search_tool.g.dart';

class TavilySearchTool extends AgentTool {
  @override
  String get name => 'tavily_search';

  @override
  String get description => tavilySearchToolDescription;

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': '搜索关键词或问题',
          },
          'max_results': {
            'type': 'integer',
            'description': '返回结果数量，1-10，默认 5',
          },
        },
        'required': ['query'],
      };

  String get _tavilyApiKey => CryptoUtil.decrypt(dotenv.env['TAVILY_API_KEY'] ?? '');

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final query = args['query'] as String?;
    if (query == null || query.isEmpty) return '错误: 请提供搜索关键词';
    final maxResults = (args['max_results'] as num?)?.toInt() ?? 5;

    if (_tavilyApiKey.isEmpty) {
      return 'Tavily 未配置 TAVILY_API_KEY，可改用 searxng_search';
    }

    try {
      final response = await _dio.post('https://api.tavily.com/search',
        data: jsonEncode({
          'api_key': _tavilyApiKey,
          'query': query,
          'max_results': maxResults,
          'include_answer': true,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final data = response.data;
      final results = data['results'] as List? ?? [];
      final answer = data['answer'] as String?;
      if (results.isEmpty) return '未找到相关搜索结果';

      final buf = StringBuffer();
      if (answer != null && answer.isNotEmpty) buf.writeln('摘要: $answer\n');
      for (int i = 0; i < results.length; i++) {
        final item = results[i] as Map;
        buf.writeln('${i + 1}. ${item['title'] ?? '无标题'}');
        buf.writeln('   ${item['content'] ?? ''}');
        buf.writeln('   ${item['url'] ?? ''}');
      }
      return buf.toString().trim();
    } on DioException catch (e) {
      return 'Tavily 搜索服务返回错误 (${e.response?.statusCode}): ${e.message}';
    } catch (e) {
      return 'Tavily 搜索失败: $e';
    }
  }
}
