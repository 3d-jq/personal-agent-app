import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../tools/base_tool.dart';
import 'searxng_search_tool.g.dart';

class SearxngSearchTool extends AgentTool {
  @override
  String get name => 'searxng_search';

  @override
  String get description => searxngSearchToolDescription;

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

  String get _searxngBaseUrl => dotenv.env['SEARXNG_BASE_URL'] ?? '';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final query = args['query'] as String?;
    if (query == null || query.isEmpty) return '错误: 请提供搜索关键词';
    final maxResults = (args['max_results'] as num?)?.toInt() ?? 5;

    if (_searxngBaseUrl.isEmpty) {
      return 'SearXNG 未配置 SEARXNG_BASE_URL，可改用 tavily_search';
    }

    try {
      final url = '$_searxngBaseUrl/search';
      final response = await _dio.get(url,
        queryParameters: {
          'q': query,
          'format': 'json',
          'categories': 'general',
          'safesearch': 0,
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );

      final data = response.data;
      final results = data['results'] as List? ?? [];
      if (results.isEmpty) return '未找到相关搜索结果';

      final buf = StringBuffer();
      for (int i = 0; i < results.length && i < maxResults; i++) {
        final item = results[i] as Map;
        buf.writeln('${i + 1}. ${item['title'] ?? '无标题'}');
        final content = item['content'] ?? '';
        if (content.toString().isNotEmpty) buf.writeln('   $content');
        buf.writeln('   ${item['url'] ?? ''}');
      }
      return buf.toString().trim();
    } catch (e) {
      return 'SearXNG 搜索失败: $e，可尝试 tavily_search';
    }
  }
}
