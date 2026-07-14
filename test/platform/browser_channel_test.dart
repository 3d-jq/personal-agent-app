import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/platform/browser_channel.dart';

void main() {
  const channelName = 'test.com.example/browser';
  late MethodChannel channel;
  late List<MethodCall> calls;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    channel = MethodChannel(channelName);
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'snapshot':
          return jsonEncode([
            {
              'ref': '0',
              'tag': 'a',
              'text': '首页',
              'type': '',
              'placeholder': '',
              'x': 1,
              'y': 2,
              'w': 3,
              'h': 4,
            },
            {
              'ref': '1',
              'tag': 'input',
              'text': '',
              'type': 'text',
              'placeholder': '搜索',
              'x': 0,
              'y': 0,
              'w': 0,
              'h': 0,
            },
          ]);
        case 'click':
          return 'clicked';
        case 'type':
          return 'typed';
        case 'fillForm':
          return 'ok';
        case 'evaluateJs':
          return '"js-result"';
        case 'tabs':
          return '[]';
        case 'back':
        case 'close':
        case 'loadUrl':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  BrowserChannel make() => BrowserChannel(channel);

  test('loadUrl 把 url 参数传给原生', () async {
    await make().loadUrl('https://example.com');
    expect(calls, hasLength(1));
    expect(calls.first.method, 'loadUrl');
    expect(calls.first.arguments['url'], 'https://example.com');
  });

  test('snapshot 解析 JSON 为 BrowserElement 列表', () async {
    final els = await make().snapshot();
    expect(els, hasLength(2));
    expect(els[0].ref, '0');
    expect(els[0].tag, 'a');
    expect(els[0].text, '首页');
    expect(els[0].x, 1);
    expect(els[0].y, 2);
    expect(els[0].w, 3);
    expect(els[0].h, 4);
    expect(els[1].placeholder, '搜索');
    expect(els[1].type, 'text');
    expect(els[1].text, isEmpty);
  });

  test('snapshot 空字符串返回空列表', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => '');
    final els = await make().snapshot();
    expect(els, isEmpty);
  });

  test('click/type/fillForm/evaluateJs 传递正确参数', () async {
    final c = make();

    expect(await c.click('5'), 'clicked');
    expect(calls.last.method, 'click');
    expect(calls.last.arguments['ref'], '5');

    expect(await c.type('3', 'hello'), 'typed');
    expect(calls.last.method, 'type');
    expect(calls.last.arguments['ref'], '3');
    expect(calls.last.arguments['text'], 'hello');

    await c.fillForm([
      {'ref': '1', 'text': 'a'},
      {'ref': '2', 'text': 'b'},
    ]);
    expect(calls.last.method, 'fillForm');
    expect(calls.last.arguments['fields'], isList);

    expect(await c.evaluateJs('1+1'), '"js-result"');
    expect(calls.last.method, 'evaluateJs');
    expect(calls.last.arguments['code'], '1+1');
  });

  test('back/close/tabs 正常调用', () async {
    final c = make();
    await c.back();
    expect(calls.last.method, 'back');
    await c.close();
    expect(calls.last.method, 'close');
    expect(await c.tabs(), '[]');
    expect(calls.last.method, 'tabs');
  });

  test('原生抛 PlatformException 时包装为 BrowserException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'X', message: '出错了');
    });
    expect(() => make().loadUrl('x'), throwsA(isA<BrowserException>()));
  });

  test('原生未实现时包装为 BrowserException（MissingPlugin）', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException('no');
    });
    expect(() => make().loadUrl('x'), throwsA(isA<BrowserException>()));
  });
}
