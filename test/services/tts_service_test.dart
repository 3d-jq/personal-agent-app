import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/tts_service.dart';

/// TtsEngine 的假实现：完全脱离平台通道，行为可由构造参数控制。
class FakeTtsEngine implements TtsEngine {
  FakeTtsEngine({
    this.zhAvailable = true,
    this.availableLangs = const ['zh-CN', 'en-US'],
    this.speakThrows = false,
  });

  final bool zhAvailable;
  final List<String> availableLangs;
  final bool speakThrows;

  final List<String> setLanguageCalls = [];
  final List<Map<String, String>> setVoiceCalls = [];
  List<dynamic> availableVoices = const [
    {'name': 'Google 普通话 (Chinese)', 'locale': 'zh-CN'},
    {'name': 'Google UK English', 'locale': 'en-GB'},
  ];
  int speakCount = 0;
  int stopCount = 0;
  void Function()? startHandler;
  void Function()? completionHandler;
  void Function(dynamic)? errorHandler;

  @override
  Future<dynamic> isLanguageAvailable(String language) async =>
      language == 'zh-CN' ? zhAvailable : false;

  @override
  Future<dynamic> getLanguages() async => availableLangs;

  @override
  Future<dynamic> getVoices() async => availableVoices;

  @override
  Future<dynamic> setLanguage(String language) async {
    setLanguageCalls.add(language);
    return true;
  }

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    setVoiceCalls.add(voice);
    return true;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async => true;
  @override
  Future<dynamic> setPitch(double pitch) async => true;
  @override
  Future<dynamic> setVolume(double volume) async => true;
  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => true;

  @override
  void setStartHandler(void Function()? handler) => startHandler = handler;
  @override
  void setCompletionHandler(void Function()? handler) =>
      completionHandler = handler;
  @override
  void setErrorHandler(void Function(dynamic)? handler) =>
      errorHandler = handler;

  @override
  Future<dynamic> stop() async {
    stopCount++;
    return true;
  }

  @override
  Future<dynamic> speak(String text) async {
    if (speakThrows) throw Exception('engine boom');
    speakCount++;
    startHandler?.call();
    return true;
  }
}

void main() {
  test('中文可用：选择 zh-CN 并朗读成功', () async {
    final fake = FakeTtsEngine();
    final svc = TtsService.withEngine(fake);
    final res = await svc.speak('你好世界');

    expect(res.success, isTrue);
    expect(res.warning, isNull);
    expect(fake.setLanguageCalls, contains('zh-CN'));
    expect(fake.speakCount, 1);
    // start 回调置为朗读中
    expect(svc.isSpeaking, isTrue);
    // completion 回调复位
    fake.completionHandler?.call();
    expect(svc.isSpeaking, isFalse);
  });

  test('zh-CN 不可用但有 zh 变体：回退选中且不误报', () async {
    final fake = FakeTtsEngine(
      zhAvailable: false,
      availableLangs: ['zh-Hans', 'en-US'],
    );
    final svc = TtsService.withEngine(fake);
    final res = await svc.speak('你好');

    expect(res.success, isTrue);
    expect(fake.setLanguageCalls, contains('zh-Hans'));
    // 选到 zh 变体即可正常朗读中文，不应误报缺包
    expect(res.warning, isNull);
  });

  test('完全无中文：仍尝试朗读并提示缺包', () async {
    final fake = FakeTtsEngine(
      zhAvailable: false,
      availableLangs: ['en-US'],
    );
    final svc = TtsService.withEngine(fake);
    final res = await svc.speak('你好');

    expect(res.success, isTrue);
    expect(fake.setLanguageCalls, isEmpty); // 没选到中文语言
    expect(fake.speakCount, 1); // 仍尽力朗读
    expect(res.warning, isNotNull);
  });

  test('空文本：不朗读、直接失败', () async {
    final fake = FakeTtsEngine();
    final svc = TtsService.withEngine(fake);
    final res = await svc.speak('   ');

    expect(res.success, isFalse);
    expect(res.error, 'empty');
    expect(fake.speakCount, 0);
  });

  test('引擎抛异常：返回失败', () async {
    final fake = FakeTtsEngine(speakThrows: true);
    final svc = TtsService.withEngine(fake);
    final res = await svc.speak('你好');

    expect(res.success, isFalse);
    expect(res.error, isNotNull);
  });

  test('朗读中经 error 回调复位状态', () async {
    final fake = FakeTtsEngine();
    final svc = TtsService.withEngine(fake);
    await svc.speak('你好');
    expect(svc.isSpeaking, isTrue);
    fake.errorHandler?.call('boom');
    expect(svc.isSpeaking, isFalse);
  });

  test('选定语音后朗读：用 setVoice 且不再用 setLanguage', () async {
    final fake = FakeTtsEngine();
    final svc = TtsService.withEngine(fake);
    svc.setSelectedVoice(const {'name': 'Google 普通话 (Chinese)', 'locale': 'zh-CN'});
    final res = await svc.speak('你好');

    expect(res.success, isTrue);
    expect(fake.setVoiceCalls, isNotEmpty);
    expect(fake.setVoiceCalls.last['name'], 'Google 普通话 (Chinese)');
    expect(fake.setLanguageCalls, isEmpty); // 选定语音时不应再 setLanguage
    expect(res.warning, isNull); // 已显式选语音，不误报缺包
  });

  test('运行时切换语音：speak 重新应用 setVoice', () async {
    final fake = FakeTtsEngine();
    final svc = TtsService.withEngine(fake);
    await svc.speak('你好');
    expect(fake.setLanguageCalls, contains('zh-CN')); // 首次用默认语言

    svc.setSelectedVoice(const {'name': 'Google UK English', 'locale': 'en-GB'});
    await svc.speak('hello');
    expect(fake.setVoiceCalls, isNotEmpty);
    expect(fake.setVoiceCalls.last['name'], 'Google UK English');
  });

  test('availableVoices 解析为 TtsVoice 列表', () async {
    final fake = FakeTtsEngine();
    final svc = TtsService.withEngine(fake);
    final voices = await svc.availableVoices();
    expect(voices, hasLength(2));
    expect(voices.first.name, 'Google 普通话 (Chinese)');
    expect(voices.first.locale, 'zh-CN');
    expect(voices.first.isChinese, isTrue);
  });

  test('清除语音选择：回退默认语言', () async {
    final fake = FakeTtsEngine();
    final svc = TtsService.withEngine(fake);
    svc.setSelectedVoice(const {'name': 'Google 普通话 (Chinese)', 'locale': 'zh-CN'});
    await svc.speak('你好');
    expect(fake.setVoiceCalls, isNotEmpty);

    svc.setSelectedVoice(null);
    await svc.speak('你好');
    expect(fake.setLanguageCalls, contains('zh-CN')); // 清除后回退语言
  });
}
