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

    Future<void> _buildAndTapVideo(
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
      await _buildAndTapVideo(tester, '![clip]($url)');

      expect(captured, isNotNull);
      expect(captured!.method, 'openFile');
      // 原生收到的应是去掉 file:// 前缀的本地路径
      expect(captured!.arguments['path'], '/data/user/0/com.example/files/clip.mp4');
      expect(captured!.arguments['mimeType'], 'video/mp4');
    });

    testWidgets('点击 mov 视频应携带正确 MIME（video/quicktime）',
        (tester) async {
      const url = 'file:///data/user/0/com.example/files/clip.mov';
      await _buildAndTapVideo(tester, '![clip]($url)');

      expect(captured, isNotNull);
      expect(captured!.arguments['mimeType'], 'video/quicktime');
    });

    testWidgets('点击 webm 视频应携带正确 MIME（video/webm）',
        (tester) async {
      const url = 'file:///data/user/0/com.example/files/clip.webm';
      await _buildAndTapVideo(tester, '![clip]($url)');

      expect(captured, isNotNull);
      expect(captured!.arguments['mimeType'], 'video/webm');
    });
  });
}
