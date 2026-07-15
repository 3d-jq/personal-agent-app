import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../../platform/browser_channel.dart';
import '../../services/log_service.dart';
import '../base_tool.dart';
import '../plugin_registry.dart';
import '../tool_registry.dart';
import 'browser_base.dart';
import '../browser_click_tool.g.dart';
import '../browser_type_tool.g.dart';
import '../browser_select_tool.g.dart';
import '../browser_fill_form_tool.g.dart';
import '../browser_evaluate_tool.g.dart';
import '../browser_screenshot_tool.g.dart';
import '../browser_hover_tool.g.dart';

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
      final r = await channel.click(ref, cssPath.isEmpty ? null : cssPath);
      if (r.startsWith('ref_not_found')) return BrowserBaseTool.friendlyError(r, '点击');
      return r;
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return BrowserBaseTool.friendlyError(e.message, '点击');
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
      final r = await channel.type(ref, text, cssPath.isEmpty ? null : cssPath);
      if (r.contains('ref_not_found')) return BrowserBaseTool.friendlyError(r, '输入');
      return r;
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return BrowserBaseTool.friendlyError(e.message, '输入');
    }
  }
}

/// 在 ref 的 `<select>` 元素中选择选项（按 value 或文本匹配）。
class BrowserSelectTool extends BrowserBaseTool {
  BrowserSelectTool(super.channel);
  @override
  String get name => 'browser_select';
  @override
  String get description => browserSelectToolDescription;
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'ref': {'type': 'string', 'description': '目标 select 元素 ref（来自 browser_snapshot）'},
          'value': {'type': 'string', 'description': '要选择的 option 的 value 或显示文本'},
          'cssPath': {'type': 'string', 'description': '可选，CSS 路径（来自 snapshot 的 cssPath 字段），用于 ref 失效时 fallback'},
        },
        'required': ['ref', 'value'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final ref = args['ref']?.toString() ?? '';
    if (ref.isEmpty) return '错误：ref 为空';
    final value = args['value']?.toString() ?? '';
    if (value.isEmpty) return '错误：value 为空';
    final cssPath = (args['cssPath'] as String? ?? '').trim();
    try {
      final r = await channel.select(ref, value, cssPath.isEmpty ? null : cssPath);
      if (r.contains('ref_not_') || r.contains('option_not_')) {
        return BrowserBaseTool.friendlyError(r, '选择', value);
      }
      return r;
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return BrowserBaseTool.friendlyError(e.message, '选择');
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
      String? b64;
      BrowserException? lastEx;
      for (var retry = 0; retry < 15; retry++) {
        try {
          b64 = await channel.screenshot();
          if (b64.isNotEmpty) break;
          await Future.delayed(const Duration(milliseconds: 200));
        } on BrowserException catch (e) {
          lastEx = e;
          // 截图失败通常是 WebView 尚未布局（宽高=0），等待重试。
          if (e.message.contains('宽高') || e.message.contains('布局')) {
            await Future.delayed(const Duration(milliseconds: 200));
          } else {
            rethrow;
          }
        }
      }
      if (b64 == null || b64.isEmpty) {
        final msg = lastEx?.message ?? '原生返回为空';
        return '浏览器截图失败：$msg（WebView 可能尚未就绪，请先打开浏览器并加载页面后再试）';
      }
      final bytes = base64Decode(b64);
      if (bytes.isEmpty) return '浏览器截图失败：解码后内容为空';
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/browser_shot_$ts.png');
      await file.writeAsBytes(bytes);
      return '浏览器截图已生成\n\n![浏览器截图](file://${file.path})';
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
      return BrowserBaseTool.friendlyError(e.message, '截图');
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
