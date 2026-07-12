import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/tts_settings.dart';

void main() {
  // path_provider 在 flutter test（尤其 Windows）环境下无原生 handler，
  // getApplicationDocumentsDirectory 会永久挂起（TimeoutException）；
  // 把该 MethodChannel mock 到系统临时目录即可解除挂起。
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

  setUp(() async {
    final f = File('${Directory.systemTemp.path}/tts_settings.json');
    if (await f.exists()) await f.delete();
    TtsSettings().resetForTest();
  });

  test('selectVoice 写入文件并刷新 getter；清除后回退', () async {
    await TtsSettings()
        .selectVoice(const {'name': 'Google 普通话', 'locale': 'zh-CN'});
    expect(TtsSettings().selectedVoiceName, 'Google 普通话');

    // 文件应已持久化
    final file = File('${Directory.systemTemp.path}/tts_settings.json');
    final written =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(written['selectedVoice']['name'], 'Google 普通话');
    expect(written['selectedVoice']['locale'], 'zh-CN');

    // 清除选择：getter 置空，文件也置空
    await TtsSettings().selectVoice(null);
    expect(TtsSettings().selectedVoice, isNull);
    final cleared =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(cleared['selectedVoice'], isNull);
  });

  test('openSystemTtsSettings 在缺少原生通道时不抛异常（返回 false）',
      () async {
    // 测试环境下没有原生 MethodChannel 实现，应被捕获并返回 false，而非崩溃。
    final ok = await openSystemTtsSettings();
    expect(ok, isFalse);
  });
}
