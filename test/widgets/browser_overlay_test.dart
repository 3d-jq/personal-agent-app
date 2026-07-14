import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/platform/browser_channel.dart';
import 'package:personal_agent_app/services/log_service.dart';
import 'package:personal_agent_app/widgets/browser_overlay.dart';

/// 测试用假浏览器通道：记录最后一次加载的 URL，snapshot 返回固定元素。
class _FakeBrowserChannel extends BrowserChannel {
  _FakeBrowserChannel() : super(const MethodChannel('test.browser.fake'));

  String? lastLoadedUrl;
  bool backCalled = false;
  bool closed = false;
  bool failLoad = false;

  @override
  Future<void> loadUrl(String url) async {
    lastLoadedUrl = url;
    if (failLoad) throw BrowserException('cannot load: $url');
  }

  @override
  Future<List<BrowserElement>> snapshot() async => const [
        BrowserElement(ref: '1', tag: 'A', text: '链接', href: 'https://x.com'),
      ];

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
  Future<void> back() async => backCalled = true;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<String> tabs() async => '[]';
}

void main() {
  testWidgets('打开即加载默认主页（不再空白）', (tester) async {
    final fake = _FakeBrowserChannel();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BrowserOverlay(channel: fake, onClose: () {})),
      ),
    );
    await tester.pumpAndSettle();
    expect(fake.lastLoadedUrl, 'https://www.baidu.com');
  });

  testWidgets('裸搜索词走 Baidu 搜索兜底', (tester) async {
    final fake = _FakeBrowserChannel();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BrowserOverlay(channel: fake, onClose: () {})),
      ),
    );
    await tester.pumpAndSettle();

    // 输入搜索词并提交
    await tester.enterText(find.byType(TextField), '天气');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(fake.lastLoadedUrl, startsWith('https://www.baidu.com/s?wd='));
    expect(fake.lastLoadedUrl, contains('%E5%A4%A9%E6%B0%94')); // 天气 的编码
  });

  testWidgets('带点的主机名补 https://', (tester) async {
    final fake = _FakeBrowserChannel();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BrowserOverlay(channel: fake, onClose: () {})),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'example.com');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(fake.lastLoadedUrl, 'https://example.com');
  });

  testWidgets('已是 http(s) 链接则原样加载', (tester) async {
    final fake = _FakeBrowserChannel();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BrowserOverlay(channel: fake, onClose: () {})),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'https://flutter.dev/docs',
    );
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(fake.lastLoadedUrl, 'https://flutter.dev/docs');
  });

  testWidgets('加载失败写入 App 运行日志（E 级）并显示错误', (tester) async {
    final lines = <String>[];
    log.setTestFileWriter((_, content) async => lines.add(content));
    log.setEnabledFlagOnly(true);
    log.setVerbose(true);

    final fake = _FakeBrowserChannel()..failLoad = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BrowserOverlay(channel: fake, onClose: () {})),
      ),
    );
    await tester.pumpAndSettle();

    // 错误文本可见
    expect(find.textContaining('cannot load'), findsWidgets);
    // 同一失败已写入 App 统一日志（运行日志页可见）
    expect(
      lines.any((l) => l.contains('[E]') && l.contains('[Browser]')),
      isTrue,
    );

    log.setTestFileWriter(null);
  });
}
