import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/platform/browser_channel.dart';
import 'package:personal_agent_app/services/log_service.dart';
import 'package:personal_agent_app/tools/browser_tool.dart';
import 'package:personal_agent_app/tools/tool_registry.dart';

/// 测试用假浏览器通道：可控制导航/快照是否失败。
class _FakeBrowserChannel extends BrowserChannel {
  _FakeBrowserChannel() : super(const MethodChannel('test.browser.tool.fake'));

  bool failLoad = false;
  bool failSnapshot = false;
  String? lastLoadedUrl;

  @override
  Future<void> loadUrl(String url) async {
    lastLoadedUrl = url;
    if (failLoad) throw BrowserException('load failed');
  }

  @override
  Future<List<BrowserElement>> snapshot() async {
    if (failSnapshot) throw BrowserException('snapshot failed');
    return const [
      BrowserElement(ref: '1', tag: 'A', text: '链接', href: 'https://x.com'),
    ];
  }

  @override
  Future<String> click(String ref) async => 'clicked $ref';
  @override
  Future<String> type(String ref, String text) async => 'typed $text';
  @override
  Future<String> fillForm(List<Map<String, String>> fields) async =>
      'filled ${fields.length}';
  @override
  Future<String> evaluateJs(String code) async => 'ok';
  @override
  Future<String> pressKey(String ref, String key) async => 'pressed $key';
  @override
  Future<void> back() async {}
  @override
  Future<void> close() async {}
  @override
  Future<String> tabs() async => '[]';
}

void main() {
  group('BrowserGotoTool', () {
    test('正常导航返回已导航', () async {
      final fake = _FakeBrowserChannel();
      final tool = BrowserGotoTool(fake);
      final r = await tool.execute({'url': 'https://example.com'});
      expect(r, contains('已导航到'));
      expect(fake.lastLoadedUrl, 'https://example.com');
    });

    test('空 url 返回错误', () async {
      final tool = BrowserGotoTool(_FakeBrowserChannel());
      final r = await tool.execute({'url': '   '});
      expect(r, contains('url 为空'));
    });

    test('导航失败记录 E 级日志并返回错误', () async {
      final lines = <String>[];
      log.setTestFileWriter((_, content) async => lines.add(content));
      log.setEnabledFlagOnly(true);
      log.setVerbose(true);

      final fake = _FakeBrowserChannel()..failLoad = true;
      final tool = BrowserGotoTool(fake);
      final r = await tool.execute({'url': 'https://bad.com'});
      expect(r, contains('浏览器导航失败'));
      expect(
        lines.any((l) => l.contains('[E]') && l.contains('[Browser]')),
        isTrue,
      );
      log.setTestFileWriter(null);
    });
  });

  group('BrowserSnapshotTool', () {
    test('正常快照格式化元素', () async {
      final tool = BrowserSnapshotTool(_FakeBrowserChannel());
      final r = await tool.execute({});
      expect(r, contains('页面元素（1）'));
      expect(r, contains('[1] A'));
    });

    test('快照失败记录 E 级日志', () async {
      final lines = <String>[];
      log.setTestFileWriter((_, content) async => lines.add(content));
      log.setEnabledFlagOnly(true);
      log.setVerbose(true);

      final fake = _FakeBrowserChannel()..failSnapshot = true;
      final tool = BrowserSnapshotTool(fake);
      final r = await tool.execute({});
      expect(r, contains('浏览器快照失败'));
      expect(
        lines.any((l) => l.contains('[E]') && l.contains('[Browser]')),
        isTrue,
      );
      log.setTestFileWriter(null);
    });
  });

  group('BrowserToolsPlugin', () {
    test('注入全部浏览器工具', () {
      final plugin = BrowserToolsPlugin(_FakeBrowserChannel());
      final registry = ToolRegistry();
      plugin.provideTools(registry);
      for (final n in [
        'browser_goto',
        'browser_snapshot',
        'browser_click',
        'browser_type',
        'browser_fill_form',
        'browser_evaluate',
        'browser_back',
        'browser_close',
      ]) {
        expect(registry.has(n), isTrue, reason: n);
      }
      expect(registry.has('terminal_run'), isFalse);
    });

    test('重复注入幂等（has 守卫）', () {
      final plugin = BrowserToolsPlugin(_FakeBrowserChannel());
      final registry = ToolRegistry();
      plugin.provideTools(registry);
      plugin.provideTools(registry);
      expect(registry.has('browser_goto'), isTrue);
    });
  });
}
