import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../platform/browser_channel.dart';
import '../services/log_service.dart';
import 'base_tool.dart';
import 'plugin_registry.dart';
import 'tool_registry.dart';
import 'browser_goto_tool.g.dart';
import 'browser_snapshot_tool.g.dart';
import 'browser_click_tool.g.dart';
import 'browser_type_tool.g.dart';
import 'browser_fill_form_tool.g.dart';
import 'browser_evaluate_tool.g.dart';
import 'browser_back_tool.g.dart';
import 'browser_close_tool.g.dart';
import 'browser_screenshot_tool.g.dart';
import 'browser_get_text_tool.g.dart';
import 'browser_get_readable_tool.g.dart';
import 'browser_get_page_info_tool.g.dart';
import 'browser_find_elements_tool.g.dart';
import 'browser_scroll_tool.g.dart';
import 'browser_wait_tool.g.dart';
import 'browser_search_tool.g.dart';
import 'browser_set_user_agent_tool.g.dart';
import 'browser_set_viewport_tool.g.dart';
import 'browser_get_cookies_tool.g.dart';
import 'browser_set_cookies_tool.g.dart';
import 'browser_hover_tool.g.dart';
import 'browser_get_backbone_tool.g.dart';
import 'browser_scroll_and_collect_tool.g.dart';

/// 浏览器工具基础类：统一持有 [BrowserChannel]，execute 委托给原生宿主。
abstract class BrowserBaseTool extends AgentTool {
  final BrowserChannel channel;

  BrowserBaseTool(this.channel);

  @override
  bool get readOnly => false;

  /// 执行 JS 并把 WebView 回调的 JSON 字符串结果解码为纯文本。
  ///
  /// WebView.evaluateJavascript 的回调值是「值的 JSON 表示」——字符串会被包成
  /// 带引号的 JSON 字符串（如 `"hello"`）。这里统一去掉外层引号，返回真实文本。
  Future<String> evalText(String code) async {
    final raw = await channel.evaluateJs(code);
    return _decodeJsString(raw);
  }

  /// 执行 JS 并把结果解析为 JSON（Map/List）。失败时返回 null。
  Future<dynamic> evalJson(String code) async {
    final raw = await channel.evaluateJs(code);
    final s = _decodeJsString(raw);
    try {
      return jsonDecode(s);
    } on FormatException {
      return null;
    }
  }
}

/// 把 WebView 返回的 JSON 字符串结果解码为真实值（字符串去外层引号）。
String _decodeJsString(String raw) {
  if (raw.isEmpty) return '';
  try {
    final d = jsonDecode(raw);
    if (d is String) return d;
    return d.toString();
  } on FormatException {
    return raw;
  }
}

/// 分页辅助：截取 [content] 的 [offset, offset+maxLen) 段；若还有剩余，
/// 末尾附「继续读取」提示，让大模型能像翻页一样拿全长内容
///（绕过全局 20000 字符工具结果截断导致大模型「看不见下文」的问题）。
String _paginate(String content, int offset, int maxLen) {
  if (content.length <= maxLen) return content;
  final end = (offset + maxLen).clamp(0, content.length);
  final slice = content.substring(offset, end);
  final remaining = content.length - end;
  if (remaining <= 0) return slice;
  return '$slice\n\n'
      '[内容较长：本段显示第 $offset–$end 字符，还剩 $remaining 字符未展示。'
      '请用 offset=$end 再次调用本工具继续读取剩余内容。]';
}

/// 导航到 URL。
class BrowserGotoTool extends BrowserBaseTool {
  BrowserGotoTool(super.channel);
  @override
  String get name => 'browser_goto';
  @override
  String get description => browserGotoToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'url': {'type': 'string', 'description': '要打开的目标网址，例如 https://www.example.com'},
        },
        'required': ['url'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final url = (args['url'] as String?)?.trim() ?? '';
    if (url.isEmpty) return '错误：url 为空';
    try {
      await channel.loadUrl(url);
      return '已导航到 $url';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '浏览器导航失败：${e.message}';
    }
  }
}

/// 获取当前页面可交互元素快照（带 ref，对齐 Playwright）。
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
class BrowserClickTool extends BrowserBaseTool {
  BrowserClickTool(super.channel);
  @override
  String get name => 'browser_click';
  @override
  String get description => browserClickToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'ref': {'type': 'string', 'description': '目标元素 ref（来自 browser_snapshot）'},
          'cssPath': {'type': 'string', 'description': '可选，CSS 路径（来自 snapshot 的 cssPath 字段）。当 React 重渲染导致 ref 失效时，可传此值作为备用定位'},
        },
        'required': ['ref'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final ref = args['ref']?.toString() ?? '';
    if (ref.isEmpty) return '错误：ref 为空';
    final cssPath = (args['cssPath'] as String? ?? '').trim();
    try {
      return await channel.click(ref, cssPath.isEmpty ? null : cssPath);
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '浏览器点击失败：${e.message}';
    }
  }
}

/// 在 ref 元素中输入文本。
class BrowserTypeTool extends BrowserBaseTool {
  BrowserTypeTool(super.channel);
  @override
  String get name => 'browser_type';
  @override
  String get description => browserTypeToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'ref': {'type': 'string', 'description': '目标输入框 ref'},
          'text': {'type': 'string', 'description': '要输入的文本'},
          'cssPath': {'type': 'string', 'description': '可选，CSS 路径（来自 snapshot 的 cssPath 字段），React 重渲染后 ref 失效时用作备用定位'},
        },
        'required': ['ref', 'text'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final ref = args['ref']?.toString() ?? '';
    final text = args['text']?.toString() ?? '';
    if (ref.isEmpty) return '错误：ref 为空';
    if (text.isEmpty) return '错误：text 为空';
    final cssPath = (args['cssPath'] as String? ?? '').trim();
    try {
      return await channel.type(ref, text, cssPath.isEmpty ? null : cssPath);
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '浏览器输入失败：${e.message}';
    }
  }
}

/// 批量填充表单。
class BrowserFillFormTool extends BrowserBaseTool {
  BrowserFillFormTool(super.channel);
  @override
  String get name => 'browser_fill_form';
  @override
  String get description => browserFillFormToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'fields': {
            'type': 'array',
            'description': '表单字段列表',
            'items': {
              'type': 'object',
              'properties': {
                'ref': {'type': 'string', 'description': '元素 ref'},
                'text': {'type': 'string', 'description': '要填入的文本'},
              },
              'required': ['ref', 'text'],
            },
          },
        },
        'required': ['fields'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final fieldsRaw = args['fields'];
    if (fieldsRaw is! List) return '错误：fields 必须是数组';
    final fields = <Map<String, String>>[];
    for (final f in fieldsRaw) {
      if (f is Map) {
        final field = <String, String>{
          'ref': (f['ref']?.toString() ?? ''),
          'text': (f['text']?.toString() ?? ''),
        };
        final cp = (f['cssPath']?.toString() ?? '').trim();
        if (cp.isNotEmpty) field['cssPath'] = cp;
        fields.add(field);
      }
    }
    if (fields.isEmpty) return '错误：fields 为空';
    try {
      return await channel.fillForm(fields);
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '浏览器填充表单失败：${e.message}';
    }
  }
}

/// 在页面执行 JavaScript。
class BrowserEvaluateTool extends BrowserBaseTool {
  BrowserEvaluateTool(super.channel);
  @override
  bool get readOnly => true;
  @override
  String get name => 'browser_evaluate';
  @override
  String get description => browserEvaluateToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'code': {'type': 'string', 'description': '要执行的 JavaScript 源码'},
        },
        'required': ['code'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final code = args['code']?.toString() ?? '';
    if (code.isEmpty) return '错误：code 为空';
    try {
      return await channel.evaluateJs(code);
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '浏览器执行 JS 失败：${e.message}';
    }
  }
}

/// 浏览器后退。
class BrowserBackTool extends BrowserBaseTool {
  BrowserBackTool(super.channel);
  @override
  String get name => 'browser_back';
  @override
  String get description => browserBackToolDescription;
  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      await channel.back();
      return '已后退';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '浏览器后退失败：${e.message}';
    }
  }
}

/// 关闭浏览器当前页面。
class BrowserCloseTool extends BrowserBaseTool {
  BrowserCloseTool(super.channel);
  @override
  String get name => 'browser_close';
  @override
  String get description => browserCloseToolDescription;
  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      await channel.close();
      return '已关闭浏览器页面';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '浏览器关闭失败：${e.message}';
    }
  }
}

/// 浏览器截图工具：截取当前 WebView 可视区域并生成图片发到对话里。
///
/// 链路：原生截图（PNG base64）→ Dart 解码存盘 →
/// 返回 `![浏览器截图](file://...)` 的 markdown。该返回串会被
/// [ai_service_base] 的 browser_screenshot 分支包成 [ToolMediaEvent] 推给
/// [ChatController]，由 inline_content 以 `Image.file` 渲染到对话气泡中，
/// 大模型也能在同一消息里「看到」这张截图（与其余工具结果一致）。
class BrowserScreenshotTool extends BrowserBaseTool {
  BrowserScreenshotTool(super.channel);
  @override
  bool get readOnly => true;
  @override
  String get name => 'browser_screenshot';
  @override
  String get description => browserScreenshotToolDescription;
  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final b64 = await channel.screenshot();
      if (b64.isEmpty) return '浏览器截图失败：原生返回为空';
      final bytes = base64Decode(b64);
      if (bytes.isEmpty) return '浏览器截图失败：解码后内容为空';
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/browser_shot_$ts.png');
      await file.writeAsBytes(bytes);
      return '浏览器截图已生成\n\n![浏览器截图](file://${file.path})';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '浏览器截图失败：${e.message}';
    } on FormatException catch (e) {
      log.e('Browser', '截图 base64 解码失败', e);
      return '浏览器截图失败：返回数据无法解码';
    } catch (e) {
      log.e('Browser', '浏览器截图异常', e);
      return '浏览器截图失败：$e';
    }
  }
}

/// 读取页面纯文本（支持分页，绕过长内容被截断的问题）。
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
      return _paginate(text, offset, maxLen);
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
      return _paginate(text, offset, maxLen);
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
class BrowserScrollTool extends BrowserBaseTool {
  BrowserScrollTool(super.channel);
  @override
  bool get readOnly => true;
  @override
  String get name => 'browser_scroll';
  @override
  String get description => browserScrollToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'delta_x': {'type': 'integer', 'description': '水平滚动像素，默认 0'},
          'delta_y': {'type': 'integer', 'description': '垂直滚动像素，默认 300（负数向上）'},
        },
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final dx = (args['delta_x'] as num?)?.toInt() ?? 0;
    final dy = (args['delta_y'] as num?)?.toInt() ?? 300;
    final code = '''
(function(){
  window.scrollBy($dx, $dy);
  return JSON.stringify({
    scrollY: window.scrollY,
    scrollHeight: document.documentElement.scrollHeight,
    innerHeight: window.innerHeight
  });
})()
''';
    try {
      final data = await evalJson(code);
      if (data is! Map) return '滚动完成';
      final y = (data['scrollY'] as num? ?? 0).toInt();
      final h = (data['scrollHeight'] as num? ?? 0).toInt();
      final vh = (data['innerHeight'] as num? ?? 0).toInt();
      final atBottom = y + vh >= h;
      return '已滚动（delta $dx,$dy）→ 位置 $y / 总高 $h（${atBottom ? '已在底部' : '可继续向下'}）';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '滚动失败：${e.message}';
    }
  }
}

/// 等待页面加载或元素出现。
class BrowserWaitTool extends BrowserBaseTool {
  BrowserWaitTool(super.channel);
  @override
  bool get readOnly => true;
  @override
  String get name => 'browser_wait';
  @override
  String get description => browserWaitToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'ms': {'type': 'integer', 'description': '等待时长（毫秒），默认 1000；dom_stable 模式下建议 3000-5000'},
          'selector': {
            'type': 'string',
            'description': '可选，CSS 选择器；传入则轮询等待该元素出现',
          },
          'dom_stable': {
            'type': 'boolean',
            'description': '可选，设为 true 则轮询等待 DOM 稳定（body 内 HTML 长度连续相同）。适用于 React/Vue SPA 页面等待客户端渲染完成。',
          },
        },
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final ms = (args['ms'] as num?)?.toInt() ?? 1000;
    final selector = (args['selector'] as String? ?? '').trim();
    final domStable = args['dom_stable'] as bool? ?? false;
    try {
      if (domStable) {
        final deadline = DateTime.now().add(Duration(milliseconds: ms));
        int last = -1;
        while (DateTime.now().isBefore(deadline)) {
          final lenStr = await evalText('document.body.innerHTML.length');
          final len = int.tryParse(lenStr.trim()) ?? 0;
          if (len > 0 && len == last) {
            return 'DOM 已稳定（HTML 长度 $len，页面加载完成）';
          }
          last = len;
          await Future.delayed(const Duration(milliseconds: 200));
        }
        return '等待超时（${ms}ms）：DOM 未稳定，可能是动态页面持续渲染';
      }
      if (selector.isNotEmpty) {
        final deadline = DateTime.now().add(Duration(milliseconds: ms));
        while (DateTime.now().isBefore(deadline)) {
          final found = await evalText(
            'document.querySelectorAll(${jsonEncode(selector)}).length',
          );
          if (found.trim() != '0' && found.trim().isNotEmpty) {
            return '已等待：元素出现 $selector';
          }
          await Future.delayed(const Duration(milliseconds: 200));
        }
        return '等待超时（${ms}ms）：$selector 未出现';
      }
      await Future.delayed(Duration(milliseconds: ms));
      return '已等待 ${ms}ms';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '等待失败：${e.message}';
    }
  }
}

/// 统一搜索入口。
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
class BrowserHoverTool extends BrowserBaseTool {
  BrowserHoverTool(super.channel);
  @override
  String get name => 'browser_hover';
  @override
  String get description => browserHoverToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'ref': {'type': 'string', 'description': '目标元素 ref（来自 browser_snapshot）'},
          'cssPath': {'type': 'string', 'description': '可选，CSS 路径（来自 snapshot 的 cssPath 字段）'},
        },
        'required': ['ref'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final ref = (args['ref'] as String? ?? '').trim();
    if (ref.isEmpty) return '错误：ref 为空';
    final cssPath = (args['cssPath'] as String? ?? '').trim();
    final sel = cssPath.isNotEmpty
        ? "document.querySelector('[data-bref=' + ${jsonEncode(ref)} + ']') || document.querySelector(${jsonEncode(cssPath)})"
        : "document.querySelector('[data-bref=' + ${jsonEncode(ref)} + ']')";
    final code = '''
(function(){
  var e = $sel;
  if (!e) return 'ref_not_found:$ref';
  e.dispatchEvent(new MouseEvent('mouseenter', {bubbles: false}));
  e.dispatchEvent(new MouseEvent('mouseover', {bubbles: true}));
  e.dispatchEvent(new MouseEvent('mousemove', {bubbles: true}));
  return 'hovered';
})()
''';
    try {
      final r = await evalText(code);
      return r.contains('ref_not_found') ? '悬停失败：未找到 ref=$ref' : '已悬停元素 $ref';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '悬停失败：${e.message}';
    }
  }
}

/// 读取 DOM 骨架树（结构概览）。
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
      return header + _paginate(text, offset, maxLen);
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return '滚动收集失败：${e.message}';
    }
  }
}

/// 浏览器能力插件：把浏览器自动化工具注入会话 ToolRegistry。
class BrowserToolsPlugin extends AppPlugin {
  final BrowserChannel channel;

  BrowserToolsPlugin([BrowserChannel? channel])
      : channel = channel ?? BrowserChannel();

  @override
  String get id => 'browser';

  @override
  Future<void> init() async {}

  @override
  void provideTools(ToolRegistry registry) {
    if (!registry.has('browser_goto')) {
      registry.register(BrowserGotoTool(channel));
    }
    if (!registry.has('browser_snapshot')) {
      registry.register(BrowserSnapshotTool(channel));
    }
    if (!registry.has('browser_click')) {
      registry.register(BrowserClickTool(channel));
    }
    if (!registry.has('browser_type')) {
      registry.register(BrowserTypeTool(channel));
    }
    if (!registry.has('browser_fill_form')) {
      registry.register(BrowserFillFormTool(channel));
    }
    if (!registry.has('browser_evaluate')) {
      registry.register(BrowserEvaluateTool(channel));
    }
    if (!registry.has('browser_back')) {
      registry.register(BrowserBackTool(channel));
    }
    if (!registry.has('browser_close')) {
      registry.register(BrowserCloseTool(channel));
    }
    if (!registry.has('browser_screenshot')) {
      registry.register(BrowserScreenshotTool(channel));
    }
    // 内容读取 / 导航 / 控制（v1.7.0 增强）
    if (!registry.has('browser_get_text')) {
      registry.register(BrowserGetTextTool(channel));
    }
    if (!registry.has('browser_get_readable')) {
      registry.register(BrowserGetReadableTool(channel));
    }
    if (!registry.has('browser_get_page_info')) {
      registry.register(BrowserGetPageInfoTool(channel));
    }
    if (!registry.has('browser_find_elements')) {
      registry.register(BrowserFindElementsTool(channel));
    }
    if (!registry.has('browser_scroll')) {
      registry.register(BrowserScrollTool(channel));
    }
    if (!registry.has('browser_wait')) {
      registry.register(BrowserWaitTool(channel));
    }
    if (!registry.has('browser_search')) {
      registry.register(BrowserSearchTool(channel));
    }
    if (!registry.has('browser_set_user_agent')) {
      registry.register(BrowserSetUserAgentTool(channel));
    }
    if (!registry.has('browser_set_viewport')) {
      registry.register(BrowserSetViewportTool(channel));
    }
    if (!registry.has('browser_get_cookies')) {
      registry.register(BrowserGetCookiesTool(channel));
    }
    if (!registry.has('browser_set_cookies')) {
      registry.register(BrowserSetCookiesTool(channel));
    }
    if (!registry.has('browser_hover')) {
      registry.register(BrowserHoverTool(channel));
    }
    if (!registry.has('browser_get_backbone')) {
      registry.register(BrowserGetBackboneTool(channel));
    }
    if (!registry.has('browser_scroll_and_collect')) {
      registry.register(BrowserScrollAndCollectTool(channel));
    }
  }
}
