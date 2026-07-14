import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/widgets/inline_content.dart';

void main() {
  group('inline video playback', () {
    const channel = MethodChannel('com.example/open_file');

    MethodCall? captured;

    setUp(() {
      captured = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'openFile') {
          captured = call;
          return true;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<void> buildAndTapVideo(
      WidgetTester tester,
      String markdown,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AgentColors.light()]),
          home: Scaffold(
            body: Builder(
              builder: (context) => SingleChildScrollView(
                child: Column(
                  children: buildInlineContent(
                    markdown,
                    AgentColors.light(),
                    context,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow).first);
      await tester.pumpAndSettle();
    }

    testWidgets('点击 mp4 视频直接调起系统播放器（video/mp4）',
        (tester) async {
      const url = 'file:///data/user/0/com.example/files/clip.mp4';
      await buildAndTapVideo(tester, '![clip]($url)');

      expect(captured, isNotNull);
      expect(captured!.method, 'openFile');
      // 原生收到的应是去掉 file:// 前缀的本地路径
      expect(captured!.arguments['path'], '/data/user/0/com.example/files/clip.mp4');
      expect(captured!.arguments['mimeType'], 'video/mp4');
    });

    testWidgets('点击 mov 视频应携带正确 MIME（video/quicktime）',
        (tester) async {
      const url = 'file:///data/user/0/com.example/files/clip.mov';
      await buildAndTapVideo(tester, '![clip]($url)');

      expect(captured, isNotNull);
      expect(captured!.arguments['mimeType'], 'video/quicktime');
    });

    testWidgets('点击 webm 视频应携带正确 MIME（video/webm）',
        (tester) async {
      const url = 'file:///data/user/0/com.example/files/clip.webm';
      await buildAndTapVideo(tester, '![clip]($url)');

      expect(captured, isNotNull);
      expect(captured!.arguments['mimeType'], 'video/webm');
    });
  });

  group('inline image preview size', () {
    Future<void> buildImage(WidgetTester tester, String markdown) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AgentColors.light()]),
          home: Scaffold(
            body: Builder(
              builder: (context) => SingleChildScrollView(
                child: Column(
                  children: buildInlineContent(
                    markdown,
                    AgentColors.light(),
                    context,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('本地截图图片高度被限制为 260（不撑满气泡）', (tester) async {
      const url = 'file:///data/user/0/com.example/files/shot.png';
      await buildImage(tester, '![浏览器截图]($url)');

      final image = tester.widget<Image>(find.byType(Image).first);
      expect(image.height, 260);
    });

    testWidgets('网络图片高度同样被限制为 260', (tester) async {
      const url = 'https://example.com/gen.png';
      await buildImage(tester, '![生成的图片]($url)');

      final image = tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first);
      expect(image.height, 260);
    });
  });
}
