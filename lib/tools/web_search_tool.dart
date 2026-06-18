import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../tools/base_tool.dart';

class WebSearchTool extends AgentTool {
  @override
  String get name => 'web_search';

  @override
  String get description => '搜索互联网获取实时信息。';

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
  String get _tavilyApiKey => dotenv.env['TAVILY_API_KEY'] ?? '';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  /// 优先用 SearXNG（自托管、免费）；没配或请求失败时回退 Tavily。
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final query = args['query'] as String?;
    if (query == null || query.isEmpty) return '错误: 请提供搜索关键词';
    final maxResults = (args['max_results'] as num?)?.toInt() ?? 5;

    // ── 优先 SearXNG ──
    if (_searxngBaseUrl.isNotEmpty) {
      try {
        return await _searchViaSearXNG(query, maxResults);
      } catch (e) {
        // SearXNG 挂了，回退 Tavily（如果配了的话）
        if (_tavilyApiKey.isEmpty) {
          return '搜索失败: SearXNG 不可用 ($e)，且未配置 Tavily 备用';
        }
        // 继续，走 Tavily
      }
    }

    // ── 回退 Tavily ──
    if (_tavilyApiKey.isEmpty) {
      return '搜索功能需要配置 SEARXNG_BASE_URL 或 TAVILY_API_KEY。'
          '自托管 SearXNG 免费，详见 .env.example';
    }
    return _searchViaTavily(query, maxResults);
  }

  Future<String> _searchViaSearXNG(String query, int maxResults) async {
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
  }

  Future<String> _searchViaTavily(String query, int maxResults) async {
    try {
      final response = await _dio.post('https://api.tavily.com/search',
        data: jsonEncode({'api_key': _tavilyApiKey, 'query': query, 'max_results': maxResults, 'include_answer': true}),
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
