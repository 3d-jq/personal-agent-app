import 'dart:async';
import 'tts_engine.dart';
import 'tts_provider.dart';
import 'tts_settings.dart';

/// 文字转语音服务（对外统一门面）。
///
/// 内部委托 [TtsProvider]（默认系统 TTS；模块 B 接入 HTTP 厂商后可由
/// [TtsProviderFactory] 切换）。本类保持稳定 API 与固定的 [speakingChanges]
/// 流：底层 Provider 实例随配置切换而重建时，UI 只需监听本门面一次。
class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._() : _provider = TtsProviderFactory.instance.current {
    _bindProvider();
  }

  /// 测试用构造：注入假引擎（底层用 [SystemTtsProvider.withEngine]）。
  TtsService.withEngine(TtsEngine engine)
      : _provider = SystemTtsProvider.withEngine(engine) {
    _bindProvider();
  }

  TtsProvider _provider;
  final StreamController<bool> _speakC = StreamController<bool>.broadcast();
  StreamSubscription? _sub;

  void _bindProvider() {
    _sub?.cancel();
    _sub = _provider.speakingChanges.listen((v) {
      if (!_speakC.isClosed) _speakC.add(v);
    });
  }

  /// 配置变化时重建底层 Provider（保持对外门面不变，UI 监听不断裂）。
  void reloadProvider() {
    _provider = TtsProviderFactory.instance.current;
    _bindProvider();
  }

  /// 是否正在朗读。
  bool get isSpeaking => _provider.isSpeaking;

  /// 朗读状态变化流（true=开始，false=停止/出错）。
  Stream<bool> get speakingChanges => _speakC.stream;

  /// 设置运行时选定的朗读语音（null 表示清除、回退默认语言）。下次朗读生效。
  void setSelectedVoice(Map<String, String>? voice) =>
      _provider.setSelectedVoice(voice);

  /// 设置语速（0..1 归一化），实时生效。
  void setRate(double rate) => _provider.setRate(rate);

  /// 设置音调（0..1 归一化），实时生效。
  void setPitch(double pitch) => _provider.setPitch(pitch);

  /// 列出设备可用 TTS 语音。
  Future<List<TtsVoice>> availableVoices() => _provider.availableVoices();

  /// 朗读文本。返回 [SpeakResult]：成功 / 带警告（缺中文语音包）/ 失败。
  Future<SpeakResult> speak(String text) => _provider.speak(text);

  /// 停止播放。
  Future<void> stop() => _provider.stop();
}
