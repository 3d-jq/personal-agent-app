import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../../platform/browser_channel.dart';
import '../../services/log_service.dart';
import '../base_tool.dart';
import '../plugin_registry.dart';
import '../tool_registry.dart';
import 'browser_base.dart';
import '../browser_goto_tool.g.dart';
import '../browser_back_tool.g.dart';
import '../browser_close_tool.g.dart';
import '../browser_scroll_tool.g.dart';
import '../browser_wait_tool.g.dart';

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
          'ref': {
            'type': 'string',
            'description': '可选，来自上一次 browser_snapshot 返回的元素 ref；传入则轮询等待该元素出现（等同 selector=data-bref=ref）',
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
    var selector = (args['selector'] as String? ?? '').trim();
    final ref = (args['ref'] as String? ?? '').trim();
    final domStable = args['dom_stable'] as bool? ?? false;
    // ref 优先级高于 selector：用 data-bref 属性查找（与 browser_click/type 一致）
    if (ref.isNotEmpty && selector.isEmpty) {
      selector = '[data-bref="$ref"]';
    }
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
