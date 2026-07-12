import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/services/tts_http_provider.dart';
import 'package:personal_agent_app/services/tts_provider.dart';
import 'package:personal_agent_app/services/tts_service.dart';
import 'package:personal_agent_app/services/tts_settings.dart';
import 'package:personal_agent_app/widgets/tts_settings_page.dart';

/// 回归守卫：当当前 TTS 厂商是 HTTP 类（OpenAI 等）时，
/// [TtsService.availableVoices] 返回 `const []`（不可修改列表）。
/// 旧代码直接在上面 .sort() 会抛
/// `Unsupported operation: Cannot modify an unmodifiable list`
/// （见崩溃日志 tts_settings_page.dart:32）。修复后先 .toList() 拷贝。
void main() {
  // 与 speech_services_settings_page_test / tts_settings_test 一致：
  // mock path_provider 通道，避免 Windows 下 getApplicationDocumentsDirectory 挂起。
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    });
  });

  setUp(() {
    // 注册并切换到 OpenAI（HTTP）厂商：availableVoices 返回 const []。
    TtsProviderFactory.instance.register(
      TtsProviderType.openai,
      () => HttpTtsProvider(
        baseUrl: 'https://fake.test/v1',
        apiKey: 'sk-test',
        model: 'tts-1',
      ),
    );
    TtsProviderFactory.instance.setType(TtsProviderType.openai);
    TtsService().reloadProvider();
    TtsSettings().resetForTest();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: const TtsSettingsPage(),
      ),
    );
  }

  testWidgets('HTTP 厂商（availableVoices 为空 const 列表）：页面不崩溃且显示空状态',
      (tester) async {
    // 若旧 bug 仍在，_loadVoices 的 .sort() 会抛「Cannot modify an unmodifiable
    // list」，该异步异常会冒泡成测试失败；能 pumpAndSettle 即代表已修复。
    await pumpPage(tester);
    await tester.pumpAndSettle();

    // 空语音列表的空状态文案应出现。
    expect(
      find.text('未读到任何 TTS 语音。请点击下方按钮在系统设置中安装语音包。'),
      findsOneWidget,
    );
    // 当前选择 / 可用语音 等分区标题仍在。
    expect(find.text('当前选择'), findsOneWidget);
    expect(find.text('可用语音'), findsOneWidget);
  });
}
