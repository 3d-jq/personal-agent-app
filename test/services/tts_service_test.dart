import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/tts_service.dart';

const _channel = MethodChannel('flutter_tts');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> called;

  setUp(() {
    called = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      called.add(call.method);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('工厂单例：多次构造返回同一实例', () {
    final a = TtsService();
    final b = TtsService();
    expect(identical(a, b), isTrue);
  });

  test('speak 触发原生 TTS 调用链并置 isSpeaking=true；stop 复位', () async {
    final tts = TtsService();
    await tts.speak('你好');

    expect(tts.isSpeaking, isTrue);
    // 初始化设置 + 打断已读 + 朗读
    expect(called, contains('setLanguage'));
    expect(called, contains('setSpeechRate'));
    expect(called, contains('setPitch'));
    expect(called, contains('setVolume'));
    expect(called, contains('speak'));

    await tts.stop();
    expect(tts.isSpeaking, isFalse);
    expect(called, contains('stop'));
  });

  test('stop 在空闲时也安全（不抛异常）', () {
    final tts = TtsService();
    expect(tts.isSpeaking, isFalse);
    expect(() async => await tts.stop(), returnsNormally);
  });
}
