import 'dart:convert';
import 'package:flutter/services.dart';

/// 浏览器会话：通过 MethodChannel 控制 Android 原生后台 WebView。
///
/// 每个会话保持一个 WebView 实例（含 cookie / localStorage），
/// AI 可导航、截屏、执行 JS。
class BrowserSession {
  static const _channel = MethodChannel('com.example/browser');

  bool _active = false;
  String? currentUrl;

  bool get isActive => _active;

  Future<void> create() async {
    if (_active) return;
    await _channel.invokeMethod('create');
    _active = true;
  }

  Future<String> navigate(String url) async {
    final json = await _channel.invokeMethod<String>('navigate', {'url': url}) ?? '{}';
    final r = jsonDecode(json) as Map<String, dynamic>;
    currentUrl = r['url']?.toString();
    return _formatResult(r);
  }

  Future<String> getSnapshot() async {
    final json = await _channel.invokeMethod<String>('snapshot') ?? '{}';
    final r = jsonDecode(json) as Map<String, dynamic>;
    currentUrl = r['url']?.toString();
    return _formatResult(r);
  }

  Future<String> click(String selector) async {
    final safeSelector = selector.replaceAll("'", "\\'");
    final js = "(function(){var el=document.querySelector('$safeSelector');if(!el)return '找不到元素';el.scrollIntoView({block:'center'});el.click();return '已点击 $safeSelector';})()";
    return await evaluateJs(js);
  }

  Future<String> type(String selector, String text) async {
    final safeSelector = selector.replaceAll("'", "\\'");
    final safeText = text.replaceAll("'", "\\'").replaceAll('\n', '\\n');
    final js = "(function(){var el=document.querySelector('$safeSelector');if(!el)return '找不到元素';el.focus();el.value='$safeText';el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));return '已输入';})()";
    return await evaluateJs(js);
  }

  Future<String> scroll(int amount) async {
    return await evaluateJs("window.scrollBy(0,$amount);'已滚动 $amount px'");
  }

  Future<String> evaluateJs(String js) async {
    return await _channel.invokeMethod<String>('evaluateJs', {'js': js}) ?? '(空)';
  }

  Future<String> screenshot() async {
    final b64 = await _channel.invokeMethod<String>('screenshot');
    if (b64 == null || b64.isEmpty) return '(截图不可用)';
    if (b64.length > 50000) {
      return '截图已生成 (${(b64.length / 1024).round()} KB base64 PNG)';
    }
    return '截图: data:image/png;base64,$b64';
  }

  Future<void> close() async {
    await _channel.invokeMethod('close');
    _active = false;
    currentUrl = null;
  }

  String _formatResult(Map<String, dynamic> result) {
    final buf = StringBuffer();
    if (result['error'] != null) {
      buf.writeln('⚠️ ${result['error']}');
      return buf.toString().trim();
    }
    if (result['title'] != null && result['title'].toString().isNotEmpty) {
      buf.writeln('【${result['title']}】');
    }
    if (result['url'] != null) buf.writeln('URL: ${result['url']}');
    buf.writeln();
    if (result['text'] != null && result['text'].toString().isNotEmpty) {
      buf.writeln('--- 页面内容 ---');
      buf.writeln(result['text']);
      buf.writeln();
    }
    final elementsRaw = result['elements'];
    if (elementsRaw is String && elementsRaw.isNotEmpty) {
      try {
        final elements = jsonDecode(elementsRaw) as List;
        if (elements.isNotEmpty) {
          buf.writeln('--- 可交互元素 (${elements.length} 个) ---');
          for (final el in elements.take(50)) {
            final m = el as Map<String, dynamic>;
            final tag = m['t'] ?? '?';
            final info = m['i']?.toString() ?? '';
            buf.writeln('  $tag | ${info.isNotEmpty ? info : "(空)"}');
          }
          if (elements.length > 50) {
            buf.writeln('  ... 还有 ${elements.length - 50} 个元素');
          }
        }
      } catch (_) {}
    }
    return buf.toString().trim();
  }
}
