import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../tools/base_tool.dart';
import 'web_fetch_tool.g.dart';

class WebFetchTool extends AgentTool {
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 25),
    followRedirects: true,
    maxRedirects: 5,
    headers: {
      'User-Agent': _userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Upgrade-Insecure-Requests': '1',
    },
    responseType: ResponseType.plain,
  ));

  @override
  String get name => 'web_fetch';

  @override
  String get description => webFetchToolDescription;

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
        'description': '返回内容的最大长度（字符数），默认 6000',
      },
    },
    'required': ['url'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final url = args['url'] as String?;
    if (url == null || url.isEmpty) return '错误: 请提供网页URL';
    final maxLen = (args['max_length'] as num?)?.toInt() ?? 6000;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return '错误: URL格式无效（需要 http:// 或 https://）';
    }
    if (!uri.scheme.startsWith('http')) {
      return '错误: 仅支持 http:// 或 https:// 协议';
    }

    // 第一次失败时重试一次，某些站点偶发连接问题
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _dio.get(
          uri.toString(),
          options: Options(responseType: ResponseType.plain),
        );

        if (response.statusCode != null &&
            (response.statusCode! < 200 || response.statusCode! >= 300)) {
          return _statusError(response.statusCode!);
        }

        final html = (response.data as String?) ?? '';
        if (html.isEmpty) return '网页内容为空';
        if (html.length < 80) return '网页内容过短，可能是跳转页或防爬页面';

        return _extractContent(html, maxLen);
      } on DioException catch (e) {
        // 最后一次尝试才返回错误
        if (attempt == 0 && _isRetryable(e)) continue;
        return _dioErrorMessage(e);
      } catch (e) {
        return '网页解析错误: $e';
      }
    }
    return '网页抓取失败，请稍后重试';
  }

  /// 提取并清洗网页正文
  String _extractContent(String html, int maxLen) {
    final document = html_parser.parse(html);

    // 移除噪声元素
    document.querySelectorAll(
      'script, style, noscript, iframe, svg, canvas, nav, footer, header, aside, '
      '[role="navigation"], [role="banner"], [role="contentinfo"], [role="complementary"], '
      '.sidebar, .nav, .footer, .header, .advertisement, .ad, .ads, .comments, .comment, '
      '.social-share, .related-posts, .recommended, #cookie-banner, #gdpr-banner'
    ).forEach((e) => e.remove());

    // 1. 优先从语义标签和常见正文容器提取
    final candidates = [
      ...document.querySelectorAll('article'),
      ...document.querySelectorAll('main'),
      document.querySelector('[role="main"]'),
      document.querySelector('.content'),
      document.querySelector('.post'),
      document.querySelector('.article'),
      document.querySelector('.entry'),
      document.querySelector('#content'),
      document.querySelector('#main'),
      document.querySelector('#article'),
    ].whereType<Element>();

    String? mainText;
    if (candidates.isNotEmpty) {
      // 选择文本最长的候选节点
      mainText = _selectBestCandidate(candidates);
    }

    // 2. 如果没找到可靠正文，退回到 body 并按段落密度启发式提取
    if (mainText == null || mainText.length < 200) {
      final body = document.body;
      if (body == null) return '无法解析网页内容';
      mainText = _extractByParagraphDensity(body);
    }

    final title = document.querySelector('title')?.text.trim() ?? '';
    final metaDesc = document.querySelector('meta[name="description"]')?.attributes['content']?.trim() ?? '';
    final h1 = document.querySelector('h1')?.text.trim() ?? '';

    // 格式化文本
    var text = mainText
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\r\n|\r'), '\n')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (text.isEmpty) return '网页未提取到有效正文';

    // 截断处理
    final bool truncated = text.length > maxLen;
    if (truncated) {
      text = text.substring(0, maxLen);
      // 尽量在段落边界截断
      final lastBreak = text.lastIndexOf('\n\n');
      if (lastBreak > maxLen * 0.8) {
        text = text.substring(0, lastBreak);
      }
    }

    final buf = StringBuffer();
    if (title.isNotEmpty && title != h1) {
      buf.writeln('标题: $title');
    }
    if (h1.isNotEmpty) {
      buf.writeln('主标题: $h1');
    }
    if (metaDesc.isNotEmpty) {
      buf.writeln('摘要: $metaDesc');
    }
    if (buf.isNotEmpty) buf.writeln('');
    buf.write(text);
    if (truncated) {
      buf.write('\n\n[内容已截断，原文较长。如需分析剩余部分，请让我继续读取。]');
    }

    return buf.toString().trim();
  }

  /// 从候选节点中选择文本最长的正文块
  String _selectBestCandidate(Iterable<Element> candidates) {
    String best = '';
    for (final el in candidates) {
      final text = _nodeText(el);
      if (text.length > best.length) best = text;
    }
    return best;
  }

  /// 按段落密度启发式提取正文：统计每个段落父节点的文本密度，返回最佳块
  String _extractByParagraphDensity(Element body) {
    final paragraphs = body.querySelectorAll('p, div, section');
    final scores = <Element, int>{};

    for (final p in paragraphs) {
      final text = _nodeText(p);
      if (text.length < 40) continue;
      final parent = p.parent;
      if (parent == null) continue;
      scores.update(parent, (value) => value + text.length, ifAbsent: () => text.length);
    }

    if (scores.isEmpty) return body.text;

    final bestEntry = scores.entries.reduce((a, b) => a.value > b.value ? a : b);
    return _nodeText(bestEntry.key);
  }

  /// 提取节点内可见文本，保留链接和图片的说明
  String _nodeText(Element node) {
    // 先把 <a>、<img> 等替换成可读的文本形式
    for (final a in node.querySelectorAll('a')) {
      final href = a.attributes['href'] ?? '';
      final text = a.text.trim();
      if (text.isEmpty) continue;
      a.replaceWith(Text(' $text${href.isNotEmpty ? '($href)' : ''} '));
    }
    for (final img in node.querySelectorAll('img')) {
      final alt = img.attributes['alt']?.trim() ?? '';
      if (alt.isNotEmpty) {
        img.replaceWith(Text('[图片: $alt] '));
      } else {
        img.remove();
      }
    }
    return node.text;
  }

  /// 是否可重试的网络错误
  bool _isRetryable(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) return true;
    if (e.type == DioExceptionType.receiveTimeout) return true;
    if (e.type == DioExceptionType.connectionError) return true;
    if (e.response?.statusCode == 503) return true;
    if (e.response?.statusCode == 502) return true;
    if (e.response?.statusCode == 504) return true;
    return false;
  }

  String _statusError(int code) {
    return switch (code) {
      400 => '请求参数错误 (400)',
      401 => '网页需要身份验证 (401)',
      403 => '网页拒绝访问 (403)，可能需要 Cookie 或浏览器环境',
      404 => '网页不存在 (404)',
      405 => '请求方法不被允许 (405)',
      429 => '请求过于频繁被限制 (429)，请稍后再试',
      500 => '网页服务器内部错误 (500)',
      502 => '网关错误 (502)',
      503 => '网页服务暂不可用 (503)',
      504 => '网关超时 (504)',
      _ => '请求失败 (HTTP $code)',
    };
  }

  String _dioErrorMessage(DioException e) {
    final code = e.response?.statusCode;
    if (code != null) return _statusError(code);

    return switch (e.type) {
      DioExceptionType.connectionTimeout => '连接超时，请检查URL或网络',
      DioExceptionType.sendTimeout => '发送请求超时',
      DioExceptionType.receiveTimeout => '接收响应超时',
      DioExceptionType.badCertificate => 'SSL证书错误，无法建立安全连接',
      DioExceptionType.badResponse => '响应格式异常',
      DioExceptionType.cancel => '请求已取消',
      DioExceptionType.connectionError => '网络连接失败，请检查网络',
      DioExceptionType.unknown => '网络请求异常: ${e.message ?? e.error}',
      _ => '抓取失败: ${e.message}',
    };
  }
}
