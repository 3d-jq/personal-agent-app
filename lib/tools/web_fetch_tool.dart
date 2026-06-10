import 'package:http/http.dart' as http;
import '../tools/base_tool.dart';

class WebFetchTool extends AgentTool {
  @override
  String get name => 'web_fetch';

  @override
  String get description => '抓取网页内容并提取正文。当用户提供URL并要求读取、总结或分析网页内容时使用。支持大多数公开网页。';

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
        'description': '返回内容的最大长度（字符数），默认 3000',
      },
    },
    'required': ['url'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final url = args['url'] as String?;
    if (url == null || url.isEmpty) {
      return '错误: 请提供网页URL';
    }

    final maxLength = (args['max_length'] as num?)?.toInt() ?? 3000;
    final uri = Uri.tryParse(url);
    if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
      return '错误: 无效的URL格式';
    }

    try {
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; PersonalAgent/1.0)',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return '网页返回错误 (${response.statusCode})';
      }

      final html = response.body;
      final text = _extractTextFromHtml(html);

      if (text.length > maxLength) {
        return '网页内容(前$maxLength字符):\n${text.substring(0, maxLength)}\n\n...(内容过长，已截断)';
      }

      return '网页内容:\n$text';
    } catch (e) {
      return '网页抓取错误: $e';
    }
  }

  /// Simple HTML to text extraction (no external dependencies)
  String _extractTextFromHtml(String html) {
    // Remove script and style elements
    String text = html
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<!--[\s\S]*?-->', caseSensitive: false), '')
        // Replace block-level elements with newlines
        .replaceAll(RegExp(r'</(?:p|div|br|hr|h[1-6]|li|tr|table|ul|ol|blockquote|pre|header|footer|section|article|aside|nav)>', caseSensitive: false), '\n')
        // Remove all remaining tags
        .replaceAll(RegExp(r'<[^>]+>'), '')
        // Decode common HTML entities
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        // Clean up whitespace
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n'), '\n\n')
        .trim();

    return text;
  }
}
