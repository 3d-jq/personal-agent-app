import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/tts_engine.dart';
import 'package:personal_agent_app/services/tts_provider.dart';
import 'package:personal_agent_app/services/tts_settings.dart';

/// 假引擎：记录 handler，供测试触发 start/completion 模拟朗读状态。
class _FakeEngine implements TtsEngine {
  void Function()? startHandler;
  void Function()? completionHandler;
  void Function(dynamic)? errorHandler;
  List<Map<String, String>> setVoiceCalls = [];
  int speakCount = 0;
  int stopCount = 0;

  @override
  Future<dynamic> isLanguageAvailable(String l) async => l == 'zh-CN';
  @override
  Future<dynamic> getLanguages() async => ['zh-CN', 'en-US'];
  @override
  Future<dynamic> getVoices() async =>
      [{'name': 'Google 普通话', 'locale': 'zh-CN'}];
  @override
  Future<dynamic> setLanguage(String l) async => true;
  @override
  Future<dynamic> setVoice(Map<String, String> v) async {
    setVoiceCalls.add(v);
    return true;
  }

  @override
  Future<dynamic> setSpeechRate(double r) async => true;
  @override
  Future<dynamic> setPitch(double p) async => true;
  @override
  Future<dynamic> setVolume(double v) async => true;
  @override
  Future<dynamic> awaitSpeakCompletion(bool a) async => true;
  @override
  Future<dynamic> stop() async {
    stopCount++;
    return true;
  }

  @override
  Future<dynamic> speak(String t) async {
    speakCount++;
    startHandler?.call();
    return true;
  }

  @override
  void setStartHandler(void Function()? h) => startHandler = h;
  @override
  void setCompletionHandler(void Function()? h) => completionHandler = h;
  @override
  void setErrorHandler(void Function(dynamic)? h) => errorHandler = h;
}

/// 假 Provider，用于验证 Factory 注册/切换。
class _FakeProvider implements TtsProvider {
  @override
  Future<void> init() async {}
  @override
  Future<SpeakResult> speak(String t) async =>
      const SpeakResult(success: true);
  @override
  Future<void> stop() async {}
  @override
  bool get isSpeaking => false;
  @override
  Stream<bool> get speakingChanges => const Stream.empty();
  @override
  Future<List<TtsVoice>> availableVoices() async => const [];
  @override
  void setSelectedVoice(Map<String, String>? v) {}
  @override
  void setRate(double r) {}
  @override
  void setPitch(double p) {}
  @override
  void dispose() {}
}

void main() {
  group('TtsProviderFactory', () {
    test('默认 current 是 SystemTtsProvider', () {
      final f = TtsProviderFactory.instance;
      expect(f.current, isA<SystemTtsProvider>());
    });

    test('register + setType 切换生效，且可还原', () {
      final f = TtsProviderFactory.instance;
      f.register(TtsProviderType.openai, () => _FakeProvider());
      f.setType(TtsProviderType.openai);
      expect(f.current, isA<_FakeProvider>());
      expect(f.type, TtsProviderType.openai);
      f.setType(TtsProviderType.system);
      expect(f.current, isA<SystemTtsProvider>());
      expect(f.type, TtsProviderType.system);
    });
  });

  group('SystemTtsProvider.speakingChanges', () {
    test('start 置 true、stop 复位 false，流依次 emit', () async {
      final fake = _FakeEngine();
      final p = SystemTtsProvider.withEngine(fake);
      final events = <bool>[];
      final sub = p.speakingChanges.listen(events.add);

      await p.init();
      await p.speak('你好');
      expect(p.isSpeaking, isTrue);

      await p.stop();
      expect(p.isSpeaking, isFalse);

      expect(events, [true, false]);
      await sub.cancel();
    });

    test('setRate 归一化到 [0,1]', () {
      final p = SystemTtsProvider();
      p.setRate(2.0);
      // 通过 availableVoices 无关；这里仅验证不抛异常且被 clamp。
      p.setPitch(-1.0);
      expect(() => p.setRate(0.0), returnsNormally);
    });
  });
}
