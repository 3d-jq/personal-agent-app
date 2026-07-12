import 'tts_engine.dart';
import 'tts_provider.dart';
import 'tts_settings.dart';

/// 文字转语音服务（对外统一门面）。
///
/// 内部委托 [TtsProvider]（默认系统 TTS；模块 B 接入 HTTP 厂商后可由
/// [TtsProviderFactory] 切换）。本类保持稳定 API，业务层只依赖它，
/// 不直接碰具体厂商实现，从而降耦合。
class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._() : _provider = TtsProviderFactory.instance.current;

  /// 测试用构造：注入假引擎（底层用 [SystemTtsProvider.withEngine]）。
  TtsService.withEngine(TtsEngine engine)
      : _provider = SystemTtsProvider.withEngine(engine);

  final TtsProvider _provider;

  /// 是否正在朗读。
  bool get isSpeaking => _provider.isSpeaking;

  /// 朗读状态变化流。
  Stream<bool> get speakingChanges => _provider.speakingChanges;

  /// 设置运行时选定的朗读语音（null 表示清除、回退默认语言）。下次朗读生效。
  void setSelectedVoice(Map<String, String>? voice) =>
      _provider.setSelectedVoice(voice);

  /// 列出设备可用 TTS 语音。
  Future<List<TtsVoice>> availableVoices() => _provider.availableVoices();

  /// 朗读文本。返回 [SpeakResult]：成功 / 带警告（缺中文语音包）/ 失败。
  Future<SpeakResult> speak(String text) => _provider.speak(text);

  /// 停止播放。
  Future<void> stop() => _provider.stop();
}
