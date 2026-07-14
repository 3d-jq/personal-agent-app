import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/platform/browser_channel.dart';
import 'package:personal_agent_app/tools/browser_tool.dart';
import 'package:personal_agent_app/tools/tool_registry.dart';

void main() {
  const channelName = 'test.com.example/browser.tools';
  late MethodChannel channel;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    channel = MethodChannel(channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'snapshot':
          return jsonEncode([
            {
              'ref': '0',
              'tag': 'a',
              'text': '登录',
              'type': '',
              'placeholder': '',
            },
            {
              'ref': '1',
              'tag': 'input',
              'text': '',
              'type': 'text',
              'placeholder': '用户名',
            },
          ]);
        case 'click':
          return 'clicked';
        case 'type':
          return 'typed';
        case 'fillForm':
          return 'ok';
        case 'evaluateJs':
          return 'result';
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

  BrowserChannel makeChannel() => BrowserChannel(channel);

  group('BrowserGotoTool', () {
    test('url 为空返回错误', () async {
      final out = await BrowserGotoTool(makeChannel()).execute({});
      expect(out, contains('url 为空'));
    });
    test('正常导航返回已导航信息', () async {
      final out =
          await BrowserGotoTool(makeChannel()).execute({'url': 'https://x.com'});
      expect(out, contains('https://x.com'));
    });
  });

  group('BrowserSnapshotTool', () {
    test('返回元素清单（含 ref 与文本）', () async {
      final out = await BrowserSnapshotTool(makeChannel()).execute({});
      expect(out, contains('[0] a'));
      expect(out, contains('登录'));
      expect(out, contains('[1] input'));
      expect(out, contains('用户名'));
    });
  });

  group('BrowserClickTool', () {
    test('ref 为空返回错误', () async {
      final out = await BrowserClickTool(makeChannel()).execute({});
      expect(out, contains('ref 为空'));
    });
    test('正常点击返回 clicked', () async {
      final out =
          await BrowserClickTool(makeChannel()).execute({'ref': '2'});
      expect(out, 'clicked');
    });
  });

  group('BrowserTypeTool', () {
    test('缺参返回错误', () async {
      final out = await BrowserTypeTool(makeChannel()).execute({'ref': '1'});
      expect(out, contains('text 为空'));
    });
    test('正常输入返回 typed', () async {
      final out = await BrowserTypeTool(makeChannel())
          .execute({'ref': '1', 'text': 'abc'});
      expect(out, 'typed');
    });
  });

  group('BrowserFillFormTool', () {
    test('fields 非数组返回错误', () async {
      final out = await BrowserFillFormTool(makeChannel()).execute({'fields': 'x'});
      expect(out, contains('fields'));
    });
    test('空 fields 返回错误', () async {
      final out = await BrowserFillFormTool(makeChannel()).execute({'fields': []});
      expect(out, contains('fields'));
    });
    test('正常填充返回 ok', () async {
      final out = await BrowserFillFormTool(makeChannel()).execute({
        'fields': [
          {'ref': '1', 'text': 'a'},
        ],
      });
      expect(out, 'ok');
    });
  });

  group('BrowserEvaluateTool', () {
    test('code 为空返回错误', () async {
      final out = await BrowserEvaluateTool(makeChannel()).execute({});
      expect(out, contains('code 为空'));
    });
    test('正常执行返回结果', () async {
      final out =
          await BrowserEvaluateTool(makeChannel()).execute({'code': '1+1'});
      expect(out, 'result');
    });
  });

  group('BrowserBackTool / BrowserCloseTool', () {
    test('后退返回已后退', () async {
      final out = await BrowserBackTool(makeChannel()).execute({});
      expect(out, '已后退');
    });
    test('关闭返回已关闭', () async {
      final out = await BrowserCloseTool(makeChannel()).execute({});
      expect(out, '已关闭浏览器页面');
    });
  });

  group('BrowserToolsPlugin', () {
    test('id 为 browser', () {
      expect(BrowserToolsPlugin(makeChannel()).id, 'browser');
    });

    test('provideTools 注入全部 8 个浏览器工具', () {
      final reg = ToolRegistry();
      BrowserToolsPlugin(makeChannel()).provideTools(reg);
      const expected = [
        'browser_goto',
        'browser_snapshot',
        'browser_click',
        'browser_type',
        'browser_fill_form',
        'browser_evaluate',
        'browser_back',
        'browser_close',
      ];
      for (final name in expected) {
        expect(reg.has(name), isTrue, reason: '缺少工具 $name');
      }
      expect(reg.all.length, expected.length);
    });

    test('provideTools 幂等：重复调用不重复注册', () {
      final reg = ToolRegistry();
      final plugin = BrowserToolsPlugin(makeChannel());
      plugin.provideTools(reg);
      plugin.provideTools(reg);
      expect(reg.all.length, 8);
    });
  });
}
