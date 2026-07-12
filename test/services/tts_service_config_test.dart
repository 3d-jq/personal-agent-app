import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/tts_provider.dart';
import 'package:personal_agent_app/services/tts_service.dart';
import 'package:personal_agent_app/services/tts_service_config.dart';

/// 与 tts_settings_test 一致：mock path_provider 通道，避免 Windows 下
/// getApplicationDocumentsDirectory 永久挂起（10 分钟超时）。
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

  File configFile() =>
      File('${Directory.systemTemp.path}/tts_service_config.json');

  test('默认 type=system，apply 后落盘 JSON', () async {
    final cfg = TtsServiceConfig.instance;
    expect(cfg.type, TtsProviderType.system);

    cfg.baseUrl = 'https://api.openai.com/v1';
    cfg.apiKey = 'sk-test';
    cfg.model = 'gpt-4o-mini-tts';
    cfg.voiceId = 'alloy';
    cfg.rate = 0.7;
    cfg.pitch = 1.0;
    await cfg.apply();

    final f = configFile();
    expect(await f.exists(), isTrue);
    final d = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    expect(d['type'], 'system');
    expect(d['baseUrl'], 'https://api.openai.com/v1');
    expect(d['model'], 'gpt-4o-mini-tts');
    expect(d['rate'], 0.7);
  });

  test('setType(openai) 后工厂切到 openai 且 TtsService 重建', () async {
    final cfg = TtsServiceConfig.instance;
    cfg.baseUrl = 'https://x.com/v1';
    cfg.apiKey = 'k';
    cfg.model = 'm';
    await cfg.setType(TtsProviderType.openai);

    expect(TtsProviderFactory.instance.type, TtsProviderType.openai);
    // 不触发真实请求（懒加载播放器），仅验证门面不抛、状态默认 false。
    expect(TtsService().isSpeaking, isFalse);
  });

  test('load 从文件恢复配置', () async {
    final f = configFile();
    await f.writeAsString(jsonEncode({
      'type': 'openai',
      'baseUrl': 'u',
      'apiKey': 'k',
      'model': 'm',
      'voiceId': 'v',
      'rate': 0.3,
      'pitch': 1.0,
    }));

    final cfg = TtsServiceConfig.instance;
    cfg.resetForTest();
    await cfg.load();

    expect(cfg.type, TtsProviderType.openai);
    expect(cfg.baseUrl, 'u');
    expect(cfg.rate, 0.3);
  });
}
