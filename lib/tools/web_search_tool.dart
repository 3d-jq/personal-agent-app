import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../tools/base_tool.dart';

class WebSearchTool extends AgentTool {
  @override
  String get name => 'web_search';

  @override
  String get description => '搜索互联网获取实时信息。当需要查询当前事件、新闻、百科知识、或任何不在训练数据中的信息时使用。';

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

  String apiKey = dotenv.env['TAVILY_API_KEY'] ?? '';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final query = args['query'] as String?;
    if (query == null || query.isEmpty) return '错误: 请提供搜索关键词';
    final maxResults = (args['max_results'] as num?)?.toInt() ?? 5;
    if (apiKey.isEmpty) return '搜索功能需要配置 API Key。请提供 Tavily API Key（免费申请: https://app.tavily.com）';

    try {
      final response = await _dio.post('https://api.tavily.com/search',
        data: jsonEncode({'api_key': apiKey, 'query': query, 'max_results': maxResults, 'include_answer': true}),
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
      return '搜索服务返回错误 (${e.response?.statusCode}): ${e.message}';
    }
  }
}
