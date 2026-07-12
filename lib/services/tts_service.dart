import 'package:flutter_tts/flutter_tts.dart';
import 'log_service.dart';
import 'tts_settings.dart';

/// TTS 引擎抽象层：隔离平台实现，便于注入假对象做单测。
/// 签名对齐 flutter_tts 4.2.5：languages 是属性(getter)，各 setter 返回 Future<dynamic>，
/// setStart/Completion/ErrorHandler 均返回 void。
abstract class TtsEngine {
  Future<dynamic> isLanguageAvailable(String language);
  Future<dynamic> getLanguages();
  Future<dynamic> getVoices();
  Future<dynamic> setLanguage(String language);
  Future<dynamic> setVoice(Map<String, String> voice);
  Future<dynamic> setSpeechRate(double rate);
  Future<dynamic> setPitch(double pitch);
  Future<dynamic> setVolume(double volume);
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion);
  Future<dynamic> stop();
  Future<dynamic> speak(String text);
  void setStartHandler(void Function()? handler);
  void setCompletionHandler(void Function()? handler);
  void setErrorHandler(void Function(dynamic)? handler);
}

/// 基于 flutter_tts 的平台实现。
class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine([FlutterTts? tts]) : _tts = tts ?? FlutterTts();
  final FlutterTts _tts;

  @override
  Future<dynamic> isLanguageAvailable(String language) =>
      _tts.isLanguageAvailable(language);
  @override
  Future<dynamic> getLanguages() => _tts.getLanguages;
  @override
  Future<dynamic> getVoices() => _tts.getVoices;
  @override
  Future<dynamic> setLanguage(String language) => _tts.setLanguage(language);
  @override
  Future<dynamic> setVoice(Map<String, String> voice) => _tts.setVoice(voice);
  @override
  Future<dynamic> setSpeechRate(double rate) => _tts.setSpeechRate(rate);
  @override
  Future<dynamic> setPitch(double pitch) => _tts.setPitch(pitch);
  @override
  Future<dynamic> setVolume(double volume) => _tts.setVolume(volume);
  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) =>
      _tts.awaitSpeakCompletion(awaitCompletion);
  @override
  Future<dynamic> stop() => _tts.stop();
  @override
  Future<dynamic> speak(String text) => _tts.speak(text);
  @override
  void setStartHandler(void Function()? handler) =>
      _tts.setStartHandler(handler ?? () {});
  @override
  void setCompletionHandler(void Function()? handler) =>
      _tts.setCompletionHandler(handler ?? () {});
  @override
  void setErrorHandler(void Function(dynamic)? handler) =>
      _tts.setErrorHandler(handler ?? (dynamic _) {});
}

/// 朗读结果：区分「成功 / 带警告（如设备缺中文语音包）/ 失败」。
class SpeakResult {
  const SpeakResult({required this.success, this.warning, this.error});
  final bool success;
  final String? warning;
  final String? error;
}

/// 文字转语音服务：包装 Android 原生 TTS 引擎，纯本地零网络。
class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._() : engine = FlutterTtsEngine();

  /// 测试用构造：注入假引擎。
  TtsService.withEngine(this.engine);

  final TtsEngine engine;
  bool _initialized = false;
  bool _speaking = false;

  /// 初始化时选定的朗读语言；为 null 表示设备无任何中文变体。
  String? _chosenLang;

  /// 用户选定的语音（来自 TtsSettings），为 null 表示用默认语言回退。
  Map<String, String>? _selectedVoice;
  String? _appliedVoiceKey;

  /// 是否正在朗读（由引擎 start/completion 回调驱动）。
  bool get isSpeaking => _speaking;

  /// 设置朗读语音（null 表示清除选择、回退默认语言）。下次朗读时生效。
  void setSelectedVoice(Map<String, String>? voice) {
    _selectedVoice = voice == null
        ? null
        : {'name': voice['name'] ?? '', 'locale': voice['locale'] ?? ''};
    if (_selectedVoice != null && _selectedVoice!['name']!.isEmpty) _selectedVoice = null;
    _appliedVoiceKey = null; // 下次 speak 重新应用
  }

  /// 列出设备可用的 TTS 语音（供设置页选择）。
  Future<List<TtsVoice>> availableVoices() async {
    try {
      final raw = await engine.getVoices();
      if (raw is! List) return const [];
      return [
        for (final v in raw)
          if (v is Map)
            TtsVoice(
              name: v['name']?.toString() ?? '',
              locale: v['locale']?.toString() ?? '',
            )
      ].where((v) => v.name.isNotEmpty).toList();
    } catch (e) {
      log.w('TtsService', '获取语音列表失败: $e');
      return const [];
    }
  }

  /// 初始化并设置语音（仅首次调用时执行）。
  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    engine.setStartHandler(() => _speaking = true);
    engine.setCompletionHandler(() => _speaking = false);
    engine.setErrorHandler((_) => _speaking = false);

    _chosenLang = await _chooseLanguage();
    await _applyVoice();
    await engine.setSpeechRate(0.5);
    await engine.setPitch(1.0);
    await engine.setVolume(1.0);
    // 让 speak() 在朗读完成时 resolve，配合 completion 回调复位状态
    await engine.awaitSpeakCompletion(true);
  }

  /// 应用当前语音选择：有选定语音用 setVoice，否则回退到选定语言。
  Future<void> _applyVoice() async {
    if (_selectedVoice != null) {
      await engine.setVoice(_selectedVoice!);
    } else if (_chosenLang != null) {
      await engine.setLanguage(_chosenLang!);
    }
    _appliedVoiceKey = _voiceKey();
  }

  String? _voiceKey() {
    if (_selectedVoice != null) {
      return 'voice:${_selectedVoice!['name']}|${_selectedVoice!['locale']}';
    }
    return 'lang:${_chosenLang ?? ''}';
  }

  /// 优先 zh-CN；设备不支持时回退到任意含 zh/cmn/yue 的语言变体；
  /// 都没有返回 null（仍尝试用引擎默认语言朗读，但会带警告）。
  Future<String?> _chooseLanguage() async {
    const preferred = 'zh-CN';
    if (await engine.isLanguageAvailable(preferred) == true) return preferred;
    final langs = await engine.getLanguages();
    if (langs is List) {
      for (final l in langs) {
        final s = l.toString().toLowerCase();
        if (s.contains('zh') || s.contains('cmn') || s.contains('yue')) {
          return l.toString();
        }
      }
    }
    return null;
  }

  /// 朗读文本。返回 SpeakResult：成功 / 带警告（缺中文语音包）/ 失败。
  Future<SpeakResult> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const SpeakResult(success: false, error: 'empty');
    }
    try {
      await _ensureInit();
    } catch (e) {
      return SpeakResult(success: false, error: 'init: ${e.toString()}');
    }
    // 运行时语音选择变化（设置页切换）则重新应用
    if (_voiceKey() != _appliedVoiceKey) {
      try {
        await _applyVoice();
      } catch (e) {
        log.w('TtsService', '应用语音选择失败: $e');
      }
    }
    try {
      await engine.stop();
      await engine.speak(trimmed);
    } catch (e) {
      return SpeakResult(success: false, error: 'speak: ${e.toString()}');
    }
    // 仅当「未选定任何语音」且「设备完全没有任何中文变体」时才提示去安装中文语音包；
    // 选到 zh-TW/zh-HK 等变体、或用户已显式选定某语音时均不误报。
    const warning = '设备未安装中文语音包，可能无法正常朗读中文。'
        '请到系统设置 → 文字转语音(TTS) 输出中安装中文语音'
        '（如 Google 文字转语音引擎的「普通话」）。';
    final needWarning = _selectedVoice == null && _chosenLang == null;
    return SpeakResult(success: true, warning: needWarning ? warning : null);
  }

  /// 停止播放。
  Future<void> stop() async {
    _speaking = false;
    await engine.stop();
  }
}
