import 'base_tool.dart';
import '../services/browser_session.dart';
import 'browser_open_tool.g.dart';
import 'browser_snapshot_tool.g.dart';
import 'browser_click_tool.g.dart';
import 'browser_type_tool.g.dart';
import 'browser_scroll_tool.g.dart';
import 'browser_screenshot_tool.g.dart';
import 'browser_evaluate_tool.g.dart';
import 'browser_close_tool.g.dart';

/// 浏览器工具。
///
/// 提供 8 个后台浏览器操作工具，AI 可导航网页、截取快照、模拟点击/输入、执行 JS。
/// 共享同一个 [BrowserSession] 实例（会话内 cookie / localStorage 保持）。
abstract class _BrowserBase extends AgentTool {
  final BrowserSession session;
  _BrowserBase(this.session);

  @override
  bool get readOnly => false;

  void _checkActive() {
    if (!session.isActive) {
      throw StateError('浏览器会话未激活，请先调用 browser_open 打开页面');
    }
  }
}

/// 打开 URL 并返回页面快照。
class BrowserOpenTool extends _BrowserBase {
  BrowserOpenTool(super.session);

  @override
  String get name => 'browser_open';
  @override
  String get description => browserOpenToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'url': {'type': 'string', 'description': '要打开的 URL'},
    },
    'required': ['url'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final url = args['url'] as String?;
    if (url == null || url.isEmpty) return '错误: 请提供 url 参数';
    if (!session.isActive) await session.create();
    return session.navigate(url);
  }
}

/// 获取当前页面快照。
class BrowserSnapshotTool extends _BrowserBase {
  BrowserSnapshotTool(super.session);

  @override
  String get name => 'browser_snapshot';
  @override
  String get description => browserSnapshotToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': <String, dynamic>{},
    'required': <String>[],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    _checkActive();
    return session.getSnapshot();
  }
}

/// 点击元素。
class BrowserClickTool extends _BrowserBase {
  BrowserClickTool(super.session);

  @override
  String get name => 'browser_click';
  @override
  String get description => browserClickToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'selector': {
        'type': 'string',
        'description': 'CSS 选择器，如 ".btn-login" 或 "[aria-label=登录]"',
      },
    },
    'required': ['selector'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    _checkActive();
    final selector = args['selector'] as String?;
    if (selector == null || selector.isEmpty) return '错误: 请提供 selector 参数';
    return session.click(selector);
  }
}

/// 填入文本。
class BrowserTypeTool extends _BrowserBase {
  BrowserTypeTool(super.session);

  @override
  String get name => 'browser_type';
  @override
  String get description => browserTypeToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'selector': {'type': 'string', 'description': '输入框的 CSS 选择器'},
      'text': {'type': 'string', 'description': '要填入的文本'},
    },
    'required': ['selector', 'text'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    _checkActive();
    final selector = args['selector'] as String?;
    final text = args['text'] as String?;
    if (selector == null || selector.isEmpty) return '错误: 请提供 selector 参数';
    if (text == null) return '错误: 请提供 text 参数';
    return session.type(selector, text);
  }
}

/// 滚动页面。
class BrowserScrollTool extends _BrowserBase {
  BrowserScrollTool(super.session);

  @override
  String get name => 'browser_scroll';
  @override
  String get description => browserScrollToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'amount': {
        'type': 'number',
        'description': '滚动像素数，正数向下、负数向上（默认 300）',
      },
    },
    'required': <String>[],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    _checkActive();
    final amount = (args['amount'] as num?)?.toInt() ?? 300;
    return session.scroll(amount);
  }
}

/// 截取页面截图。
class BrowserScreenshotTool extends _BrowserBase {
  BrowserScreenshotTool(super.session);

  @override
  String get name => 'browser_screenshot';
  @override
  String get description => browserScreenshotToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': <String, dynamic>{},
    'required': <String>[],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    _checkActive();
    return session.screenshot();
  }
}

/// 执行 JavaScript。
class BrowserEvaluateTool extends _BrowserBase {
  BrowserEvaluateTool(super.session);

  @override
  String get name => 'browser_evaluate';
  @override
  String get description => browserEvaluateToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'js': {'type': 'string', 'description': '要执行的 JavaScript 代码'},
    },
    'required': ['js'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    _checkActive();
    final js = args['js'] as String?;
    if (js == null || js.isEmpty) return '错误: 请提供 js 参数';
    return session.evaluateJs(js);
  }
}

/// 关闭浏览器会话。
class BrowserCloseTool extends _BrowserBase {
  BrowserCloseTool(super.session);

  @override
  String get name => 'browser_close';
  @override
  String get description => browserCloseToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': <String, dynamic>{},
    'required': <String>[],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    await session.close();
    return '浏览器会话已关闭';
  }
}
