import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/platform/browser_channel.dart';
import 'package:personal_agent_app/tools/browser_tool.dart';
import 'package:personal_agent_app/tools/tool_registry.dart';

const _kChannelName = 'browser_unit_test';

MethodChannel _mockChannel(dynamic Function(MethodCall) handler) {
  final c = MethodChannel(_kChannelName);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(c, (call) async => handler(call));
  return c;
}

void _clearMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(MethodChannel(_kChannelName), null);
}

/// 模拟 WebView 对「字符串结果」的 JSON 包装（evaluateJavascript 回调会把字符串包成带引号的 JSON）。
String _jsString(String s) => jsonEncode(s);

/// 模拟 WebView 对「JSON.stringify(obj) 结果」的包装（再被 JSON 包一层）。
String _jsJson(dynamic obj) => jsonEncode(jsonEncode(obj));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(_clearMock);

  test('BrowserElement 解析 inViewport/visible/disabled 新字段', () async {
    final ch = _mockChannel((call) {
      if (call.method == 'snapshot') {
        return jsonEncode([
          {'ref': '0', 'tag': 'button', 'text': '提交', 'inViewport': true, 'visible': true, 'disabled': false},
          {'ref': '1', 'tag': 'a', 'text': '', 'inViewport': false, 'visible': false, 'disabled': false},
          {'ref': '2', 'tag': 'input', 'text': '', 'inViewport': true, 'visible': true, 'disabled': true},
        ]);
      }
      return null;
    });
    final els = await BrowserChannel(ch).snapshot();
    expect(els.length, 3);
    expect(els[0].visible, isTrue);
    expect(els[1].visible, isFalse);
    expect(els[1].inViewport, isFalse);
    expect(els[2].disabled, isTrue);
  });

  test('BrowserSnapshotTool 输出标注 offscreen/hidden/disabled', () async {
    final ch = _mockChannel((call) {
      if (call.method == 'snapshot') {
        return jsonEncode([
          {'ref': '0', 'tag': 'button', 'text': '提交', 'inViewport': true, 'visible': true, 'disabled': false},
          {'ref': '1', 'tag': 'a', 'text': '外链', 'inViewport': false, 'visible': true, 'disabled': false},
          {'ref': '2', 'tag': 'input', 'text': '', 'inViewport': true, 'visible': true, 'disabled': true},
        ]);
      }
      return null;
    });
    final r = await BrowserSnapshotTool(BrowserChannel(ch)).execute({});
    expect(r, contains('提交'));
    expect(r, contains('offscreen'));
    expect(r, contains('disabled'));
  });

  test('BrowserGetTextTool 分页续读（绕过 20000 截断）', () async {
    final long = 'A' * 20000;
    final ch = _mockChannel((call) {
      if (call.method == 'evaluateJs') return _jsString(long);
      return null;
    });
    final tool = BrowserGetTextTool(BrowserChannel(ch));
    final r1 = await tool.execute({'offset': 0, 'max_length': 6000});
    expect(r1.length, lessThan(20000));
    expect(r1, contains('内容较长'));
    expect(r1, contains('offset=6000'));
    final r2 = await tool.execute({'offset': 6000, 'max_length': 6000});
    expect(r2, contains('offset=12000'));
    final r3 = await tool.execute({'offset': 18000, 'max_length': 6000});
    expect(r3, isNot(contains('内容较长')));
  });

  test('BrowserGetReadableTool 支持分页', () async {
    final long = 'B' * 20000;
    final ch = _mockChannel((call) {
      if (call.method == 'evaluateJs') return _jsString(long);
      return null;
    });
    final r = await BrowserGetReadableTool(BrowserChannel(ch)).execute({'max_length': 5000});
    expect(r, contains('内容较长'));
    expect(r, contains('offset=5000'));
  });

  test('BrowserGetPageInfoTool 解析结构化信息', () async {
    final info = {
      'title': 'T', 'url': 'https://x.com', 'readyState': 'complete',
      'scrollY': 0, 'scrollHeight': 1000, 'innerWidth': 390, 'innerHeight': 844, 'elementCount': 50,
    };
    final ch = _mockChannel((call) {
      if (call.method == 'evaluateJs') return _jsJson(info);
      return null;
    });
    final r = await BrowserGetPageInfoTool(BrowserChannel(ch)).execute({});
    expect(r, contains('T'));
    expect(r, contains('https://x.com'));
    expect(r, contains('可继续向下'));
  });

  test('BrowserFindElementsTool 解析 CSS 选择器结果', () async {
    final data = {
      'count': 3, 'shown': 1,
      'items': [{'tag': 'a', 'id': '', 'cls': 'link', 'text': 'Go', 'href': 'https://g.com', 'value': '', 'type': ''}],
    };
    final ch = _mockChannel((call) {
      if (call.method == 'evaluateJs') return _jsJson(data);
      return null;
    });
    final r = await BrowserFindElementsTool(BrowserChannel(ch)).execute({'selector': 'a.link'});
    expect(r, contains('匹配 3 个元素'));
    expect(r, contains('Go'));
    expect(r, contains('https://g.com'));
  });

  test('BrowserScrollTool 返回滚动位置与到底判定', () async {
    final data = {'scrollY': 300, 'scrollHeight': 5000, 'innerHeight': 844};
    final ch = _mockChannel((call) {
      if (call.method == 'evaluateJs') return _jsJson(data);
      return null;
    });
    final r = await BrowserScrollTool(BrowserChannel(ch)).execute({'delta_y': 300});
    expect(r, contains('已滚动'));
    expect(r, contains('可继续向下'));
  });

  test('BrowserWaitTool 固定等待', () async {
    final ch = _mockChannel((call) => null);
    final sw = Stopwatch()..start();
    final r = await BrowserWaitTool(BrowserChannel(ch)).execute({'ms': 200});
    sw.stop();
    expect(r, contains('已等待 200ms'));
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(150));
  });

  test('BrowserWaitTool selector 等待元素出现', () async {
    final ch = _mockChannel((call) {
      if (call.method == 'evaluateJs') return '3';
      return null;
    });
    final r = await BrowserWaitTool(BrowserChannel(ch)).execute({'ms': 1000, 'selector': '.x'});
    expect(r, contains('元素出现'));
  });

  test('BrowserSearchTool 打开搜索引擎', () async {
    String? loaded;
    final ch = _mockChannel((call) {
      if (call.method == 'loadUrl') {
        loaded = call.arguments['url'];
        return null;
      }
      return null;
    });
    final r = await BrowserSearchTool(BrowserChannel(ch)).execute({'query': 'flutter'});
    expect(loaded, contains('bing.com/search'));
    expect(loaded, contains('flutter'));
    expect(r, contains('已在浏览器打开搜索'));
  });

  test('BrowserSetUserAgentTool 转发 UA', () async {
    String? ua;
    final ch = _mockChannel((call) {
      if (call.method == 'setUserAgent') {
        ua = call.arguments['ua'];
        return null;
      }
      return null;
    });
    final r = await BrowserSetUserAgentTool(BrowserChannel(ch)).execute({'ua': 'Mozilla/5.0 Mobile'});
    expect(ua, 'Mozilla/5.0 Mobile');
    expect(r, contains('已设置 UA'));
  });

  test('BrowserSetViewportTool 转发宽高', () async {
    Map? vp;
    final ch = _mockChannel((call) {
      if (call.method == 'setViewport') {
        vp = call.arguments;
        return 'ok';
      }
      return null;
    });
    final r = await BrowserSetViewportTool(BrowserChannel(ch)).execute({'width': 390, 'height': 844});
    expect(vp?['width'], 390);
    expect(vp?['height'], 844);
    expect(r, contains('视口已设置为 390 x 844'));
  });

  test('BrowserGetCookiesTool 返回 Cookie', () async {
    final ch = _mockChannel((call) {
      if (call.method == 'getCookies') return 'a=1; b=2';
      return null;
    });
    final r = await BrowserGetCookiesTool(BrowserChannel(ch)).execute({});
    expect(r, contains('a=1'));
  });

  test('BrowserSetCookiesTool 转发 Cookie', () async {
    Map? sc;
    final ch = _mockChannel((call) {
      if (call.method == 'setCookies') {
        sc = call.arguments;
        return null;
      }
      return null;
    });
    final r = await BrowserSetCookiesTool(BrowserChannel(ch)).execute({'cookies': 'a=1; b=2'});
    expect(sc?['cookies'], 'a=1; b=2');
    expect(r, contains('已设置 Cookie'));
  });

  test('BrowserHoverTool 派发悬停事件', () async {
    final ch = _mockChannel((call) {
      if (call.method == 'evaluateJs') return _jsString('hovered');
      return null;
    });
    final r = await BrowserHoverTool(BrowserChannel(ch)).execute({'ref': '2'});
    expect(r, contains('已悬停元素 2'));
  });

  test('BrowserGetBackboneTool 返回 DOM 骨架', () async {
    final tree = '<div>\n  <span>hi</span>\n';
    final ch = _mockChannel((call) {
      if (call.method == 'evaluateJs') return _jsString(tree);
      return null;
    });
    final r = await BrowserGetBackboneTool(BrowserChannel(ch)).execute({});
    expect(r, contains('DOM 骨架'));
    expect(r, contains('<div>'));
  });

  test('BrowserScrollAndCollectTool 返回收集文本', () async {
    final data = {'steps': 5, 'blocks': 3, 'text': 'block1\n\nblock2\n\nblock3'};
    final ch = _mockChannel((call) {
      if (call.method == 'evaluateJs') return _jsJson(data);
      return null;
    });
    final r = await BrowserScrollAndCollectTool(BrowserChannel(ch)).execute({});
    expect(r, contains('滚动收集完成'));
    expect(r, contains('block1'));
  });

  test('BrowserChannel 控制方法参数正确', () async {
    final captured = <String, dynamic>{};
    final ch = _mockChannel((call) {
      captured[call.method] = call.arguments;
      if (call.method == 'getCookies') return 'x=1';
      if (call.method == 'setViewport') return 'ok';
      return null;
    });
    final bc = BrowserChannel(ch);
    await bc.setUserAgent('UA1');
    await bc.setViewport(100, 200);
    final c = await bc.getCookies('https://a.com');
    await bc.setCookies('k=v', 'https://a.com');
    expect(captured['setUserAgent']['ua'], 'UA1');
    expect(captured['setViewport']['width'], 100);
    expect(captured['setViewport']['height'], 200);
    expect(captured['getCookies']['url'], 'https://a.com');
    expect(captured['setCookies']['cookies'], 'k=v');
    expect(captured['setCookies']['url'], 'https://a.com');
    expect(c, 'x=1');
  });

  test('BrowserToolsPlugin 注册全部 24 个浏览器工具', () {
    final registry = ToolRegistry();
    BrowserToolsPlugin().provideTools(registry);
    const expected = [
      'browser_goto', 'browser_snapshot', 'browser_click', 'browser_type',
      'browser_fill_form', 'browser_evaluate', 'browser_back', 'browser_close',
      'browser_screenshot', 'browser_get_text', 'browser_get_readable',
      'browser_get_page_info', 'browser_find_elements', 'browser_scroll',
      'browser_wait', 'browser_search', 'browser_set_user_agent',
      'browser_set_viewport', 'browser_get_cookies', 'browser_set_cookies',
      'browser_hover', 'browser_get_backbone', 'browser_scroll_and_collect',
      'browser_select',
    ];
    for (final n in expected) {
      expect(registry.has(n), isTrue, reason: '缺少 $n');
    }
    expect(registry.all.length, expected.length);
  });
}
