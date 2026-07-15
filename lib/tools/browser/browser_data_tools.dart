import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../../platform/browser_channel.dart';
import '../../services/log_service.dart';
import '../base_tool.dart';
import '../plugin_registry.dart';
import '../tool_registry.dart';
import 'browser_base.dart';
import '../browser_snapshot_tool.g.dart';
import '../browser_get_text_tool.g.dart';
import '../browser_get_readable_tool.g.dart';
import '../browser_get_page_info_tool.g.dart';
import '../browser_find_elements_tool.g.dart';
import '../browser_search_tool.g.dart';
import '../browser_set_user_agent_tool.g.dart';
import '../browser_set_viewport_tool.g.dart';
import '../browser_get_cookies_tool.g.dart';
import '../browser_set_cookies_tool.g.dart';
import '../browser_get_backbone_tool.g.dart';
import '../browser_scroll_and_collect_tool.g.dart';

class BrowserSnapshotTool extends BrowserBaseTool {
  BrowserSnapshotTool(super.channel);
  @override
  bool get readOnly => true;
  @override
  String get name => 'browser_snapshot';
  @override
  String get description => browserSnapshotToolDescription;
  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final els = await channel.snapshot();
      if (els.isEmpty) return '页面暂无可见的可交互元素（可能仍在加载或无表单）。';
      final lines = els.map((e) {
        final parts = <String>['[${e.ref}] ${e.tag}'];
        if (e.text.isNotEmpty) parts.add('text="${e.text}"');
        if (e.placeholder.isNotEmpty) parts.add('placeholder="${e.placeholder}"');
        if (e.href.isNotEmpty) parts.add('href="${e.href}"');
        if (e.value.isNotEmpty) parts.add('value="${e.value}"');
        if (e.cssPath.isNotEmpty) parts.add('path=${e.cssPath}');
        final flags = <String>[];
        if (e.disabled) flags.add('disabled');
        if (!e.visible) flags.add('hidden');
        if (!e.inViewport) flags.add('offscreen');
        if (flags.isNotEmpty) parts.add('(${flags.join(',')})');
        return parts.join(' ');
      }).toList();
      return '页面元素（${els.length}，优先操作 visible 且非 disabled 的）：\n${lines.join('\n')}';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '浏览器快照失败：${e.message}';
    }
  }
}

/// 按 ref 点击元素。
class BrowserGetTextTool extends BrowserBaseTool {
  BrowserGetTextTool(super.channel);
  @override
  bool get readOnly => true;
  @override
  String get name => 'browser_get_text';
  @override
  String get description => browserGetTextToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'offset': {
            'type': 'integer',
            'description': '起始字符偏移（用于分页续读），默认 0',
          },
          'max_length': {
            'type': 'integer',
            'description': '本次最多返回的字符数，默认 6000，最大 18000',
          },
        },
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final offset = ((args['offset'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30);
    var maxLen = (args['max_length'] as num?)?.toInt() ?? 6000;
    if (maxLen <= 0 || maxLen > 18000) maxLen = 18000;
    try {
      final text = await evalText('document.body.innerText');
      if (text.isEmpty) return '页面暂无可见文本（可能仍在加载或内容为纯图片）。';
      return topPaginate(text, offset, maxLen);
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '读取页面文本失败：${e.message}';
    }
  }
}

/// 读取页面可读正文（去噪，适合长文/文章）。
class BrowserGetReadableTool extends BrowserBaseTool {
  BrowserGetReadableTool(super.channel);
  @override
  bool get readOnly => true;
  @override
  String get name => 'browser_get_readable';
  @override
  String get description => browserGetReadableToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'offset': {'type': 'integer', 'description': '起始字符偏移（分页续读），默认 0'},
          'max_length': {
            'type': 'integer',
            'description': '本次最多返回的字符数，默认 6000，最大 18000',
          },
        },
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final offset = ((args['offset'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30);
    var maxLen = (args['max_length'] as num?)?.toInt() ?? 6000;
    if (maxLen <= 0 || maxLen > 18000) maxLen = 18000;
    const code = r'''
(function(){
  try {
    var clone = document.body.cloneNode(true);
    var rm = clone.querySelectorAll('script,style,noscript,nav,header,footer,aside,form,svg,iframe,button,iframe');
    for (var i = 0; i < rm.length; i++) { rm[i].remove(); }
    var cand = clone.querySelector('article, main, [role=main], .content, #content, .post, .article, .markdown-body');
    var root = cand || clone;
    return (root.innerText || '').replace(/\s+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim();
  } catch (err) { return ''; }
})()
''';
    try {
      final text = await evalText(code);
      if (text.isEmpty) return '未能提取到可读正文（页面可能无文字内容）。';
      return topPaginate(text, offset, maxLen);
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '提取正文失败：${e.message}';
    }
  }
}

/// 读取页面结构化信息（标题/URL/尺寸等）。
class BrowserGetPageInfoTool extends BrowserBaseTool {
  BrowserGetPageInfoTool(super.channel);
  @override
  bool get readOnly => true;
  @override
  String get name => 'browser_get_page_info';
  @override
  String get description => browserGetPageInfoToolDescription;
  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    const code = '''
(function(){
  return JSON.stringify({
    title: document.title,
    url: location.href,
    readyState: document.readyState,
    scrollY: window.scrollY,
    scrollHeight: document.documentElement.scrollHeight,
    innerWidth: window.innerWidth,
    innerHeight: window.innerHeight,
    elementCount: document.querySelectorAll('*').length
  });
})()
''';
    try {
      final data = await evalJson(code);
      if (data is! Map) return '获取页面信息失败：返回格式异常';
      final atBottom = (data['scrollY'] as num? ?? 0) +
              (data['innerHeight'] as num? ?? 0) >=
          (data['scrollHeight'] as num? ?? 0);
      return '页面信息：\n'
          '标题: ${data['title']}\n'
          'URL: ${data['url']}\n'
          '加载状态: ${data['readyState']}\n'
          '滚动位置: ${data['scrollY']} / 总高 ${data['scrollHeight']}（${atBottom ? '已在底部' : '可继续向下滚动'}）\n'
          '视口: ${data['innerWidth']}x${data['innerHeight']}\n'
          '元素总数: ${data['elementCount']}';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '获取页面信息失败：${e.message}';
    }
  }
}

/// 按 CSS 选择器查找元素（结构化返回）。
class BrowserFindElementsTool extends BrowserBaseTool {
  BrowserFindElementsTool(super.channel);
  @override
  bool get readOnly => true;
  @override
  String get name => 'browser_find_elements';
  @override
  String get description => browserFindElementsToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS 选择器，例如 "a", ".news-item", "#results div"',
          },
          'limit': {
            'type': 'integer',
            'description': '最多展示的元素数，默认 50',
          },
        },
        'required': ['selector'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final sel = (args['selector'] as String? ?? '').trim();
    if (sel.isEmpty) return '错误：selector 为空';
    final limit = (args['limit'] as num?)?.toInt() ?? 50;
    final code = '''
(function(){
  var sel = ${jsonEncode(sel)};
  var max = $limit;
  var els = document.querySelectorAll(sel);
  var out = [];
  for (var i = 0; i < els.length && i < max; i++) {
    var e = els[i];
    out.push({
      tag: e.tagName ? e.tagName.toLowerCase() : '',
      id: e.id || '',
      cls: (e.className || '').toString().slice(0, 80),
      text: (e.innerText || e.value || '').toString().slice(0, 80),
      href: e.href || '',
      value: e.value || '',
      type: e.type || ''
    });
  }
  return JSON.stringify({count: els.length, shown: out.length, items: out});
})()
''';
    try {
      final data = await evalJson(code);
      if (data is! Map) return '查找元素失败：返回格式异常';
      final count = data['count'] ?? 0;
      final shown = data['shown'] ?? 0;
      final items = data['items'];
      if (items is! List || items.isEmpty) return '未匹配到任何元素：selector=$sel';
      final lines = items.map((it) {
        final m = it as Map;
        final parts = <String>['<${m['tag']}>'];
        if ((m['id'] ?? '').toString().isNotEmpty) parts.add('#${m['id']}');
        if ((m['cls'] ?? '').toString().isNotEmpty) parts.add('.${m['cls']}');
        final txt = (m['text'] ?? '').toString();
        if (txt.isNotEmpty) parts.add('"$txt"');
        if ((m['href'] ?? '').toString().isNotEmpty) parts.add('→ ${m['href']}');
        return parts.join(' ');
      }).toList();
      return '匹配 $count 个元素（展示 $shown）：$sel\n${lines.join('\n')}';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '查找元素失败：${e.message}';
    }
  }
}

/// 滚动页面。
class BrowserSearchTool extends BrowserBaseTool {
  BrowserSearchTool(super.channel);
  @override
  String get name => 'browser_search';
  @override
  String get description => browserSearchToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': '搜索关键词'},
          'engine': {
            'type': 'string',
            'description': '搜索引擎：bing / google / duckduckgo / baidu，默认 bing',
          },
        },
        'required': ['query'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final query = (args['query'] as String? ?? '').trim();
    if (query.isEmpty) return '错误：query 为空';
    final engine = (args['engine'] as String? ?? 'bing').toLowerCase();
    String url;
    switch (engine) {
      case 'google':
        url = 'https://www.google.com/search?q=${Uri.encodeQueryComponent(query)}';
      case 'duckduckgo':
        url = 'https://duckduckgo.com/?q=${Uri.encodeQueryComponent(query)}';
      case 'baidu':
        url = 'https://www.baidu.com/s?wd=${Uri.encodeQueryComponent(query)}';
      case 'bing':
      default:
        url = 'https://www.bing.com/search?q=${Uri.encodeQueryComponent(query)}';
    }
    try {
      await channel.loadUrl(url);
      return '已在浏览器打开搜索（$engine）：$query\n$url\n'
          '（建议 browser_wait(800) 后 browser_get_text 读取结果）';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '搜索失败：${e.message}';
    }
  }
}

/// 切换浏览器 User-Agent。
class BrowserSetUserAgentTool extends BrowserBaseTool {
  BrowserSetUserAgentTool(super.channel);
  @override
  String get name => 'browser_set_user_agent';
  @override
  String get description => browserSetUserAgentToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'ua': {
            'type': 'string',
            'description': 'UA 字符串；为空则恢复默认桌面 UA',
          },
        },
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final ua = (args['ua'] as String? ?? '').trim();
    try {
      await channel.setUserAgent(ua);
      return ua.isEmpty ? '已恢复默认桌面 UA' : '已设置 UA：$ua';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '设置 UA 失败：${e.message}';
    }
  }
}

/// 设置视口尺寸。
class BrowserSetViewportTool extends BrowserBaseTool {
  BrowserSetViewportTool(super.channel);
  @override
  String get name => 'browser_set_viewport';
  @override
  String get description => browserSetViewportToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'width': {'type': 'integer', 'description': '视口宽度（CSS 像素），如 390 模拟手机'},
          'height': {'type': 'integer', 'description': '视口高度（CSS 像素），如 844 模拟手机'},
        },
        'required': ['width', 'height'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final w = (args['width'] as num?)?.toInt() ?? 0;
    final h = (args['height'] as num?)?.toInt() ?? 0;
    if (w <= 0 || h <= 0) return '错误：width/height 必须大于 0';
    try {
      final r = await channel.setViewport(w, h);
      return '视口已设置为 $w x $h：$r';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '设置视口失败：${e.message}';
    }
  }
}

/// 读取 Cookie。
class BrowserGetCookiesTool extends BrowserBaseTool {
  BrowserGetCookiesTool(super.channel);
  @override
  bool get readOnly => true;
  @override
  String get name => 'browser_get_cookies';
  @override
  String get description => browserGetCookiesToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': '可选，指定 URL；留空则取当前页',
          },
        },
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final url = (args['url'] as String? ?? '').trim();
    try {
      final cookies = await channel.getCookies(url.isEmpty ? null : url);
      return cookies.isEmpty ? '(无 Cookie)' : cookies;
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '读取 Cookie 失败：${e.message}';
    }
  }
}

/// 设置 Cookie（保持登录态等）。
class BrowserSetCookiesTool extends BrowserBaseTool {
  BrowserSetCookiesTool(super.channel);
  @override
  String get name => 'browser_set_cookies';
  @override
  String get description => browserSetCookiesToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'cookies': {
            'type': 'string',
            'description': 'Cookie 字符串，多个用分号分隔',
          },
          'url': {'type': 'string', 'description': '可选，指定 URL；留空则当前页'},
        },
        'required': ['cookies'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final cookies = (args['cookies'] as String? ?? '').trim();
    if (cookies.isEmpty) return '错误：cookies 为空';
    final url = (args['url'] as String? ?? '').trim();
    try {
      await channel.setCookies(cookies, url.isEmpty ? null : url);
      return '已设置 Cookie（${cookies.split(';').where((c) => c.trim().isNotEmpty).length} 项）';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '设置 Cookie 失败：${e.message}';
    }
  }
}

/// 悬停元素（触发菜单/浮层）。
class BrowserGetBackboneTool extends BrowserBaseTool {
  BrowserGetBackboneTool(super.channel);
  @override
  bool get readOnly => true;
  @override
  String get name => 'browser_get_backbone';
  @override
  String get description => browserGetBackboneToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'max_depth': {'type': 'integer', 'description': '遍历最大深度，默认 4'},
          'max_nodes': {'type': 'integer', 'description': '最多输出的节点数，默认 200'},
        },
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final maxDepth = (args['max_depth'] as num?)?.toInt() ?? 4;
    final maxNodes = (args['max_nodes'] as num?)?.toInt() ?? 200;
    final code = r'''
(function(){
  var MAXD = __MAXD__, MAXN = __MAXN__, n = 0;
  function walk(node, depth){
    if (!node || n >= MAXN || depth > MAXD) return '';
    if (node.nodeType !== 1) return '';
    n++;
    var tag = node.tagName.toLowerCase();
    var info = tag;
    if (node.id) info += '#' + node.id;
    var cls = (node.className || '').toString().split(/\s+/)[0];
    if (cls) info += '.' + cls;
    var txt = (node.innerText || '').toString().replace(/\s+/g, ' ').trim().slice(0, 30);
    var line = '  '.repeat(depth) + '<' + info + '>' + (txt ? ' ' + txt : '');
    var children = '';
    for (var i = 0; i < node.children.length && n < MAXN; i++) {
      children += walk(node.children[i], depth + 1);
    }
    return line + '\n' + children;
  }
  return walk(document.body, 0);
})()
'''
        .replaceAll('__MAXD__', maxDepth.toString())
        .replaceAll('__MAXN__', maxNodes.toString());
    try {
      final tree = await evalText(code);
      if (tree.isEmpty) return '页面无 DOM 结构可提取';
      return 'DOM 骨架（max_depth=$maxDepth, max_nodes=$maxNodes）：\n$tree';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '读取 DOM 骨架失败：${e.message}';
    }
  }
}

/// 滚动并收集内容（适合无限滚动页面）。
class BrowserScrollAndCollectTool extends BrowserBaseTool {
  BrowserScrollAndCollectTool(super.channel);
  @override
  bool get readOnly => true;
  @override
  String get name => 'browser_scroll_and_collect';
  @override
  String get description => browserScrollAndCollectToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'delta_y': {'type': 'integer', 'description': '每次滚动像素，默认 800'},
          'steps': {'type': 'integer', 'description': '滚动次数，默认 5'},
          'selector': {
            'type': 'string',
            'description': '可选，只收集匹配该 CSS 选择器的元素文本',
          },
          'offset': {'type': 'integer', 'description': '起始字符偏移（分页续读），默认 0'},
          'max_length': {
            'type': 'integer',
            'description': '本次最多返回的字符数，默认 6000，最大 18000',
          },
        },
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final dy = (args['delta_y'] as num?)?.toInt() ?? 800;
    final steps = (args['steps'] as num?)?.toInt() ?? 5;
    final sel = (args['selector'] as String? ?? '').trim();
    final offset = ((args['offset'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30);
    var maxLen = (args['max_length'] as num?)?.toInt() ?? 6000;
    if (maxLen <= 0 || maxLen > 18000) maxLen = 18000;
    final code = '''
(function(){
  var dy = $dy;
  var steps = $steps;
  var sel = ${sel.isEmpty ? 'null' : jsonEncode(sel)};
  var collected = [];
  var seen = {};
  for (var s = 0; s < steps; s++) {
    var nodes = sel ? document.querySelectorAll(sel) : [document.body];
    for (var i = 0; i < nodes.length; i++) {
      var t = (nodes[i].innerText || '').toString().trim();
      if (t && !seen[t]) { seen[t] = 1; collected.push(t); }
    }
    window.scrollBy(0, dy);
  }
  return JSON.stringify({steps: steps, blocks: collected.length, text: collected.join('\\n\\n')});
})()
''';
    try {
      final data = await evalJson(code);
      if (data is! Map) return '滚动收集失败：返回格式异常';
      final text = (data['text'] ?? '').toString();
      if (text.isEmpty) return '滚动收集未获取到文本（页面可能无文字内容）';
      final header = '滚动收集完成（${data['steps']} 次，命中 ${data['blocks']} 个文本块）：\n';
      return header + topPaginate(text, offset, maxLen);
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '滚动收集失败：${e.message}';
    }
  }
}

/// 浏览器能力插件：把浏览器自动化工具注入会话 ToolRegistry。
