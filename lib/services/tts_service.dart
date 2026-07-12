import 'package:flutter_tts/flutter_tts.dart';

/// 文字转语音服务：包装 Android 原生 TTS 引擎，纯本地零网络。
class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  /// 初始化并设置中文语音（首次调用时自动执行）
  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  /// 朗读文本。正在播放时会先停止再读（打断模式）。
  Future<void> speak(String text) async {
    await _ensureInit();
    await _tts.stop();
    await _tts.speak(text);
    _speaking = true;
    // flutter_tts speak 完成后没有回调，用简单启发式
    final words = text.split(RegExp(r'\s+')).length;
    final estimatedMs = (words / 3 * 1000).round().clamp(2000, 60000);
    Future.delayed(Duration(milliseconds: estimatedMs), () {
      _speaking = false;
    });
  }

  /// 停止播放
  Future<void> stop() async {
    _speaking = false;
    await _tts.stop();
  }
}
