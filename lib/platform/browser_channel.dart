import 'dart:convert';

import 'package:flutter/services.dart';

/// 浏览器原生通道异常（如平台未实现、WebView 不可用）。
class BrowserException implements Exception {
  final String message;
  final Object? cause;
  const BrowserException(this.message, [this.cause]);

  @override
  String toString() => 'BrowserException: $message';
}

/// 浏览器快照中的单个可交互元素（对齐 Playwright 的 accessibility ref）。
class BrowserElement {
  final String ref;
  final String tag;
  final String text;
  final String type;
  final String name;
  final String id;
  final String placeholder;
  final String href;
  final String value;
  final int x;
  final int y;
  final int w;
  final int h;
  /// 元素是否位于当前视口内（几何判断）。
  final bool inViewport;
  /// 元素是否实际可见（尺寸、display/visibility/opacity 均正常且在视口内）。
  final bool visible;
  /// 元素是否被禁用（disabled 属性或 disabled 状态）。
  final bool disabled;

  const BrowserElement({
    required this.ref,
    required this.tag,
    this.text = '',
    this.type = '',
    this.name = '',
    this.id = '',
    this.placeholder = '',
    this.href = '',
    this.value = '',
    this.x = 0,
    this.y = 0,
    this.w = 0,
    this.h = 0,
    this.inViewport = false,
    this.visible = false,
    this.disabled = false,
  });

  factory BrowserElement.fromJson(Map<String, dynamic> j) => BrowserElement(
        ref: j['ref']?.toString() ?? '',
        tag: j['tag']?.toString() ?? '',
        text: j['text']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        id: j['id']?.toString() ?? '',
        placeholder: j['placeholder']?.toString() ?? '',
        href: j['href']?.toString() ?? '',
        value: j['value']?.toString() ?? '',
        x: (j['x'] as num?)?.toInt() ?? 0,
        y: (j['y'] as num?)?.toInt() ?? 0,
        w: (j['w'] as num?)?.toInt() ?? 0,
        h: (j['h'] as num?)?.toInt() ?? 0,
        inViewport: j['inViewport'] as bool? ?? false,
        visible: j['visible'] as bool? ?? false,
        disabled: j['disabled'] as bool? ?? false,
      );
}

/// 浏览器原生能力通道封装。
///
/// 封装 `MethodChannel('com.example/browser')`，把 Kotlin 原生 [WebView] 宿主
/// 暴露的自动化能力以类型安全的方式提供给 Dart 侧（工具层 / UI 层）。
///
/// 可注入 [MethodChannel] 以便测试（默认使用真实通道名）。
class BrowserChannel {
  static const String channelName = 'com.example/browser';
  static const String viewType = 'browser_webview';

  final MethodChannel _channel;

  BrowserChannel([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(channelName);

  /// 导航到指定 URL。
  Future<void> loadUrl(String url) => _invoke('loadUrl', {'url': url});

  /// 当前页面 URL（未加载 / 已关闭时为 null 或空串）。
  /// 用于浏览器浮层判断：当大模型已导航到某页面时，不再强制覆盖。
  Future<String> currentUrl() => _invoke<String>('currentUrl');

  /// 获取当前页面可交互元素快照（带 ref）。
  Future<List<BrowserElement>> snapshot() async {
    final raw = await _invoke<String>('snapshot');
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(BrowserElement.fromJson)
            .toList();
      }
    } on FormatException {
      // 原生返回非 JSON（如 '[]' 字符串）时回退为空
    }
    return const [];
  }

  /// 按 ref 点击元素。
  Future<String> click(String ref) =>
      _invoke('click', {'ref': ref});

  /// 在 ref 元素中输入文本。
  Future<String> type(String ref, String text) =>
      _invoke('type', {'ref': ref, 'text': text});

  /// 批量填充表单字段：[{ref, text}, ...]。
  Future<String> fillForm(List<Map<String, String>> fields) =>
      _invoke('fillForm', {
        'fields': fields.map((f) => f.cast<String, dynamic>()).toList(),
      });

  /// 在页面执行 JS 并返回结果字符串。
  Future<String> evaluateJs(String code) => _invoke('evaluateJs', {'code': code});

  /// 按 ref 派发键盘事件。
  Future<String> pressKey(String ref, String key) =>
      _invoke('pressKey', {'ref': ref, 'key': key});

  /// 浏览器后退。
  Future<void> back() => _invoke('back');

  /// 关闭当前页面（清空 WebView）。
  Future<void> close() => _invoke('close');

  /// 当前标签页（暂返回空列表，预留扩展）。
  Future<String> tabs() => _invoke('tabs');

  /// 截取当前 WebView 可视区域为 PNG，返回 base64 字符串（NO_WRAP）。
  /// 空串表示原生未就绪或截图失败；WebView 尚未布局时 throws [BrowserException]。
  Future<String> screenshot() => _invoke<String>('screenshot');

  /// 设置浏览器 User-Agent。传空串恢复默认桌面 UA。
  Future<void> setUserAgent(String ua) => _invoke('setUserAgent', {'ua': ua});

  /// 设置视口（通过注入 meta viewport 让响应式站点按指定宽度重排）。
  /// 返回 "ok" 或错误提示。
  Future<String> setViewport(int width, int height) =>
      _invoke('setViewport', {'width': width, 'height': height});

  /// 获取 Cookie（默认当前页 URL，可指定 [url]）。
  Future<String> getCookies([String? url]) =>
      _invoke('getCookies', url != null ? {'url': url} : null);

  /// 设置 Cookie（多个以分号分隔；默认作用于当前页 URL）。
  Future<void> setCookies(String cookies, [String? url]) => _invoke(
        'setCookies',
        url != null ? {'cookies': cookies, 'url': url} : {'cookies': cookies},
      );

  Future<T> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      final result = await _channel.invokeMethod<T>(method, args);
      return result as T;
    } on PlatformException catch (e) {
      throw BrowserException(
        e.message ?? '浏览器操作失败: $method',
        e,
      );
    } on MissingPluginException catch (e) {
      throw BrowserException('浏览器原生模块未就绪（请使用 Android 构建）', e);
    }
  }
}
