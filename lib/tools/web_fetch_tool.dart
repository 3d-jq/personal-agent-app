import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../tools/base_tool.dart';

class WebFetchTool extends AgentTool {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    followRedirects: true,
    maxRedirects: 5,
    headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
    },
    responseType: ResponseType.plain,
  ));

  @override
  String get name => 'web_fetch';

  @override
  String get description => '抓取网页内容并提取正文。当用户给出 URL 并要求读取、总结、分析该网页时使用。不要对未抓取的网页内容做猜测。';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'url': {
        'type': 'string',
        'description': '要抓取的网页URL',
      },
      'max_length': {
        'type': 'integer',
        'description': '返回内容的最大长度（字符数），默认 5000',
      },
    },
    'required': ['url'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final url = args['url'] as String?;
    if (url == null || url.isEmpty) return '错误: 请提供网页URL';
    final maxLen = (args['max_length'] as num?)?.toInt() ?? 5000;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return '错误: URL格式无效（需要 http:// 或 https://）';

    try {
      final response = await _dio.get(uri.toString(),
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode != 200) {
        return '请求失败 (HTTP ${response.statusCode})';
      }

      final html = response.data as String;
      if (html.isEmpty || html.length < 100) {
        return '网页内容为空或过短';
      }

      // Parse HTML and extract meaningful text
      final document = html_parser.parse(html);

      // Remove noise elements
      document.querySelectorAll('script, style, noscript, iframe, nav, footer, header, aside, [role="navigation"], [role="banner"], [role="contentinfo"], .sidebar, .nav, .footer, .header, .advertisement, .ad, .comments').forEach((e) => e.remove());

      // Try to find main content area
      var body = document.querySelector('main, article, [role="main"], .content, .post, .article, #content, #main, #article');
      body ??= document.body;

      if (body == null) return '无法解析网页内容';

      // Extract title
      final title = document.querySelector('title')?.text.trim() ?? '';
      // Extract meta description
      final metaDesc = document.querySelector('meta[name="description"]')?.attributes['content']?.trim() ?? '';

      // Get text content
      String text = body.text
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();

      // Build result
      final buf = StringBuffer();
      if (title.isNotEmpty) buf.writeln('标题: $title');
      if (metaDesc.isNotEmpty) buf.writeln('摘要: $metaDesc');
      if (buf.isNotEmpty) buf.writeln('');
      buf.write(text.length > maxLen ? '${text.substring(0, maxLen)}...(已截断)' : text);

      return buf.toString().trim();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) return '网页不存在 (404)';
      if (code == 403) return '网页拒绝访问 (403)';
      if (e.type == DioExceptionType.connectionTimeout) return '连接超时，请检查URL或网络';
      return '抓取失败: ${e.message}';
    } catch (e) {
      return '网页抓取错误: $e';
    }
  }
}
