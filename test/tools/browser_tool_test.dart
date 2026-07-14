import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/platform/browser_channel.dart';
import 'package:personal_agent_app/services/log_service.dart';
import 'package:personal_agent_app/tools/browser_tool.dart';
import 'package:personal_agent_app/tools/tool_registry.dart';

/// 1x1 透明 PNG 的 base64（用于截图工具测试，可正常解码为 PNG 字节）。
const String _kFakePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQAY3Y2wAAAAAElFTkSuQmCC';

/// 测试用假浏览器通道：可控制导航/快照/截图是否失败。
class _FakeBrowserChannel extends BrowserChannel {
  _FakeBrowserChannel() : super(const MethodChannel('test.browser.tool.fake'));

  bool failLoad = false;
  bool failSnapshot = false;
  bool failScreenshot = false;
  String screenshotValue = _kFakePngBase64;
  String? lastLoadedUrl;

  @override
  Future<void> loadUrl(String url) async {
    lastLoadedUrl = url;
    if (failLoad) throw BrowserException('load failed');
  }

  @override
  Future<List<BrowserElement>> snapshot() async {
    if (failSnapshot) throw BrowserException('snapshot failed');
    return [
      BrowserElement(
        ref: '1', tag: 'A', text: '链接', href: 'https://x.com',
        visible: true, inViewport: true,
      ),
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
  @override
  Future<String> screenshot() async {
    if (failScreenshot) throw BrowserException('screenshot failed');
    return screenshotValue;
  }
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
      expect(r, contains('页面元素（1，优先操作 visible 且非 disabled 的）'));
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
        'browser_screenshot',
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

  group('BrowserScreenshotTool', () {
    /// 给 path_provider 的 getApplicationDocumentsDirectory 打桩，返回可写临时目录。
    Future<String> mockDocsDir() async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      final dir = Directory.systemTemp.createTempSync('bshot');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return dir.path;
          }
          return null;
        },
      );
      return dir.path;
    }

    test('正常截图：解码存盘并返回 file:// markdown', () async {
      final docs = await mockDocsDir();
      final fake = _FakeBrowserChannel();
      final tool = BrowserScreenshotTool(fake);
      final r = await tool.execute({});
      expect(r, contains('浏览器截图已生成'));
      expect(r, contains('![浏览器截图](file://'));

      final m = RegExp(r'file://([^)\s]+)').firstMatch(r);
      expect(m, isNotNull);
      final path = m!.group(1)!;
      expect(File(path).existsSync(), isTrue);
      // 文件落在打桩的临时目录内
      expect(path, startsWith(docs));
    });

    test('截图返回空串时给出友好错误', () async {
      await mockDocsDir();
      final fake = _FakeBrowserChannel()..screenshotValue = '';
      final tool = BrowserScreenshotTool(fake);
      final r = await tool.execute({});
      expect(r, contains('浏览器截图失败'));
    });

    test('截图失败记录 E 级日志并返回错误', () async {
      final lines = <String>[];
      log.setTestFileWriter((_, content) async => lines.add(content));
      log.setEnabledFlagOnly(true);
      log.setVerbose(true);

      await mockDocsDir();
      final fake = _FakeBrowserChannel()..failScreenshot = true;
      final tool = BrowserScreenshotTool(fake);
      final r = await tool.execute({});
      expect(r, contains('浏览器截图失败'));
      expect(
        lines.any((l) => l.contains('[E]') && l.contains('[Browser]')),
        isTrue,
      );
      log.setTestFileWriter(null);
    });
  });
}
