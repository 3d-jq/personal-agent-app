import '../platform/browser_channel.dart';
import 'base_tool.dart';
import 'plugin_registry.dart';
import 'tool_registry.dart';

/// 浏览器工具基础类：统一持有 [BrowserChannel]，execute 委托给原生宿主。
abstract class BrowserBaseTool extends AgentTool {
  final BrowserChannel channel;

  BrowserBaseTool(this.channel);

  @override
  bool get readOnly => false;
}

/// 导航到 URL。
class BrowserGotoTool extends BrowserBaseTool {
  BrowserGotoTool(super.channel);
  @override
  String get name => 'browser_goto';
  @override
  String get description =>
      '让内置浏览器打开指定网址。参数 url 为目标链接。打开后可用 browser_snapshot 获取页面可交互元素。';
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
    await channel.loadUrl(url);
    return '已导航到 $url';
  }
}

/// 获取当前页面可交互元素快照（带 ref，对齐 Playwright）。
class BrowserSnapshotTool extends BrowserBaseTool {
  BrowserSnapshotTool(super.channel);
  @override
  String get name => 'browser_snapshot';
  @override
  String get description =>
      '获取当前浏览器页面的可交互元素清单（按钮/链接/输入框等），每个元素带 ref。后续 click/type 用 ref 定位元素。';
  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final els = await channel.snapshot();
    if (els.isEmpty) return '页面暂无可见的可交互元素（可能仍在加载或无表单）。';
    final lines = els.map((e) {
      final parts = <String>['[${e.ref}] ${e.tag}'];
      if (e.text.isNotEmpty) parts.add('text="${e.text}"');
      if (e.placeholder.isNotEmpty) parts.add('placeholder="${e.placeholder}"');
      if (e.href.isNotEmpty) parts.add('href="${e.href}"');
      if (e.value.isNotEmpty) parts.add('value="${e.value}"');
      return parts.join(' ');
    }).toList();
    return '页面元素（${els.length}）：\n${lines.join('\n')}';
  }
}

/// 按 ref 点击元素。
class BrowserClickTool extends BrowserBaseTool {
  BrowserClickTool(super.channel);
  @override
  String get name => 'browser_click';
  @override
  String get description => '按 browser_snapshot 返回的 ref 点击页面元素。';
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'ref': {'type': 'string', 'description': '目标元素 ref（来自 browser_snapshot）'},
        },
        'required': ['ref'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final ref = args['ref']?.toString() ?? '';
    if (ref.isEmpty) return '错误：ref 为空';
    return await channel.click(ref);
  }
}

/// 在 ref 元素中输入文本。
class BrowserTypeTool extends BrowserBaseTool {
  BrowserTypeTool(super.channel);
  @override
  String get name => 'browser_type';
  @override
  String get description => '在 browser_snapshot 返回的 ref 输入框中输入文本（会触发 input 事件）。';
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'ref': {'type': 'string', 'description': '目标输入框 ref'},
          'text': {'type': 'string', 'description': '要输入的文本'},
        },
        'required': ['ref', 'text'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final ref = args['ref']?.toString() ?? '';
    final text = args['text']?.toString() ?? '';
    if (ref.isEmpty) return '错误：ref 为空';
    if (text.isEmpty) return '错误：text 为空';
    return await channel.type(ref, text);
  }
}

/// 批量填充表单。
class BrowserFillFormTool extends BrowserBaseTool {
  BrowserFillFormTool(super.channel);
  @override
  String get name => 'browser_fill_form';
  @override
  String get description => '批量填充表单字段，fields 为 [{ref, text}, ...]。';
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
        fields.add({
          'ref': (f['ref']?.toString() ?? ''),
          'text': (f['text']?.toString() ?? ''),
        });
      }
    }
    if (fields.isEmpty) return '错误：fields 为空';
    return await channel.fillForm(fields);
  }
}

/// 在页面执行 JavaScript。
class BrowserEvaluateTool extends BrowserBaseTool {
  BrowserEvaluateTool(super.channel);
  @override
  String get name => 'browser_evaluate';
  @override
  String get description => '在浏览器页面执行 JavaScript 代码并返回结果（字符串）。';
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
    return await channel.evaluateJs(code);
  }
}

/// 浏览器后退。
class BrowserBackTool extends BrowserBaseTool {
  BrowserBackTool(super.channel);
  @override
  String get name => 'browser_back';
  @override
  String get description => '浏览器后退到上一页。';
  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    await channel.back();
    return '已后退';
  }
}

/// 关闭浏览器当前页面。
class BrowserCloseTool extends BrowserBaseTool {
  BrowserCloseTool(super.channel);
  @override
  String get name => 'browser_close';
  @override
  String get description => '关闭浏览器当前页面（清空 WebView）。';
  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    await channel.close();
    return '已关闭浏览器页面';
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
  }
}
