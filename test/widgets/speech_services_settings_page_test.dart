import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/services/tts_provider.dart';
import 'package:personal_agent_app/services/tts_service.dart';
import 'package:personal_agent_app/services/tts_service_config.dart';
import 'package:personal_agent_app/widgets/speech_services_settings_page.dart';

/// 与 tts_settings_test 一致：mock path_provider 通道，避免 Windows 下挂起。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    },
  );

  setUp(() {
    TtsServiceConfig.instance.resetForTest();
    TtsProviderFactory.instance.setType(TtsProviderType.system);
    TtsService().reloadProvider();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: Builder(builder: (c) => const SpeechServicesSettingsPage()),
      ),
    );
  }

  testWidgets('默认 system：显示朗读语音/安装语音包，不显示 HTTP 配置', (tester) async {
    await pumpPage(tester);
    expect(find.text('语音服务'), findsOneWidget);
    expect(find.text('朗读语音'), findsOneWidget);
    expect(find.text('安装语音包'), findsOneWidget);
    expect(find.text('Base URL'), findsNothing);
  });

  testWidgets('切到 OpenAI：显示 HTTP 配置卡并接线工厂', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    expect(find.text('Base URL'), findsOneWidget);
    expect(find.text('API Key'), findsOneWidget);
    // 切换后工厂已切到 openai（配置落地 + 接线）。
    expect(TtsProviderFactory.instance.type, TtsProviderType.openai);
  });
}
