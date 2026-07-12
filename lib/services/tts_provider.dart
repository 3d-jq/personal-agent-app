import 'dart:async';
import 'tts_engine.dart';
import 'tts_settings.dart';
import 'log_service.dart';

/// TTS 厂商类型。系统 TTS 当前完整可用；
/// HTTP 类厂商（OpenAI / MiniMax / SiliconFlow / 豆包等）由模块 B 注册接入。
enum TtsProviderType {
  system,
  openai,
  minimax,
  siliconflow,
  doubao,
}

/// 朗读结果：区分「成功 / 带警告（如设备缺中文语音包）/ 失败」。
class SpeakResult {
  const SpeakResult({required this.success, this.warning, this.error});
  final bool success;
  final String? warning;
  final String? error;
}

/// TTS 抽象层：屏蔽「系统 TTS / 各家 HTTP TTS」差异，对齐 Operit VoiceService 能力。
///
/// 设计目标（借鉴 Operit）：
/// - [speak] 归一化 rate/pitch/volume（系统 TTS 内部再映射到底层范围）
/// - [speakingChanges] 暴露朗读状态流，UI 可实时显示「朗读中/已停止」
/// - [availableVoices] 返回可选语音（系统 TTS 才有；HTTP 厂商通常只有一个 voiceId）
abstract class TtsProvider {
  /// 初始化（首次 speak 前或配置变更时）。
  Future<void> init();

  /// 朗读文本。rate/pitch/volume 为归一化参数（默认值 0.5/1.0/1.0）。
  Future<SpeakResult> speak(String text);

  /// 停止播放。
  Future<void> stop();

  /// 是否正在朗读（由引擎 start/completion 回调驱动）。
  bool get isSpeaking;

  /// 朗读状态变化流（true=开始，false=停止/出错）。
  Stream<bool> get speakingChanges;

  /// 列出可用语音（供设置页选择）。系统 TTS 返回设备语音列表。
  Future<List<TtsVoice>> availableVoices();

  /// 运行时设置选定语音（null 表示清除选择、回退默认语言）。下次朗读生效。
  void setSelectedVoice(Map<String, String>? voice);

  /// 设置语速（0..1 归一化，默认 0.5）。
  void setRate(double rate);

  /// 设置音调（0..1 归一化，默认 1.0）。
  void setPitch(double pitch);

  /// 释放资源。
  void dispose();
}

/// 系统 TTS 实现（基于 flutter_tts，纯本地零网络）。
///
/// 逻辑与原 [TtsService] 内部一致：优先 zh-CN，回退任意含 zh 变体，
/// 都没有仍尝试朗读但带「缺中文语音包」警告；运行时切换语音则重新 apply。
class SystemTtsProvider implements TtsProvider {
  SystemTtsProvider([this._engineFactory])
      : _rate = 0.5,
        _pitch = 1.0;

  /// 测试构造：注入假引擎工厂。
  SystemTtsProvider.withEngine(TtsEngine engine)
      : _engineFactory = (() => engine),
        _rate = 0.5,
        _pitch = 1.0;

  final TtsEngine Function()? _engineFactory;
  TtsEngine get _engine =>
      _engineFactory == null ? FlutterTtsEngine() : _engineFactory();

  double _rate;
  double _pitch;
  final double _volume = 1.0;

  bool _initialized = false;
  bool _speaking = false;

  /// 初始化时选定的朗读语言；为 null 表示设备无任何中文变体。
  String? _chosenLang;

  /// 用户选定的语音（来自 TtsSettings），为 null 表示用默认语言回退。
  Map<String, String>? _selectedVoice;
  String? _appliedVoiceKey;

  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get speakingChanges => _speakingController.stream;

  @override
  bool get isSpeaking => _speaking;

  void _setSpeaking(bool v) {
    _speaking = v;
    if (!_speakingController.isClosed) _speakingController.add(v);
  }

  @override
  void setRate(double rate) => _rate = rate.clamp(0.0, 1.0);
  @override
  void setPitch(double pitch) => _pitch = pitch.clamp(0.0, 1.0);

  @override
  void setSelectedVoice(Map<String, String>? voice) {
    _selectedVoice = voice == null
        ? null
        : {'name': voice['name'] ?? '', 'locale': voice['locale'] ?? ''};
    if (_selectedVoice != null && _selectedVoice!['name']!.isEmpty) {
      _selectedVoice = null;
    }
    _appliedVoiceKey = null; // 下次 speak 重新应用
  }

  @override
  Future<List<TtsVoice>> availableVoices() async {
    try {
      final raw = await _engine.getVoices();
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
      log.w('SystemTtsProvider', '获取语音列表失败: $e');
      return const [];
    }
  }

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _engine.setStartHandler(() => _setSpeaking(true));
    _engine.setCompletionHandler(() => _setSpeaking(false));
    _engine.setErrorHandler((_) => _setSpeaking(false));

    _chosenLang = await _chooseLanguage();
    await _applyVoice();
    await _engine.setSpeechRate(_rate);
    await _engine.setPitch(_pitch);
    await _engine.setVolume(_volume);
    await _engine.awaitSpeakCompletion(true);
  }

  Future<void> _applyVoice() async {
    if (_selectedVoice != null) {
      await _engine.setVoice(_selectedVoice!);
    } else if (_chosenLang != null) {
      await _engine.setLanguage(_chosenLang!);
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
    if (await _engine.isLanguageAvailable(preferred) == true) return preferred;
    final langs = await _engine.getLanguages();
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

  @override
  Future<SpeakResult> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const SpeakResult(success: false, error: 'empty');
    }
    try {
      await init();
    } catch (e) {
      return SpeakResult(success: false, error: 'init: ${e.toString()}');
    }
    // 语速/音调可能已被设置页调整，每次朗读前同步。
    try {
      await _engine.setSpeechRate(_rate);
      await _engine.setPitch(_pitch);
      await _engine.setVolume(_volume);
    } catch (e) {
      log.w('SystemTtsProvider', '应用语速/音调失败: $e');
    }
    // 运行时语音选择变化（设置页切换）则重新应用。
    if (_voiceKey() != _appliedVoiceKey) {
      try {
        await _applyVoice();
      } catch (e) {
        log.w('SystemTtsProvider', '应用语音选择失败: $e');
      }
    }
    try {
      await _engine.stop();
      await _engine.speak(trimmed);
    } catch (e) {
      return SpeakResult(success: false, error: 'speak: ${e.toString()}');
    }
    const warning = '设备未安装中文语音包，可能无法正常朗读中文。'
        '请到系统设置 → 文字转语音(TTS) 输出中安装中文语音'
        '（如 Google 文字转语音引擎的「普通话」）。';
    final needWarning = _selectedVoice == null && _chosenLang == null;
    return SpeakResult(success: true, warning: needWarning ? warning : null);
  }

  @override
  Future<void> stop() async {
    _setSpeaking(false);
    await _engine.stop();
  }

  @override
  void dispose() {
    if (!_speakingController.isClosed) _speakingController.close();
  }
}

/// TTS 厂商工厂：按 [TtsProviderType] 返回对应的 [TtsProvider]。
///
/// 采用「可注册 builder」模式：默认注册 [TtsProviderType.system]；
/// 模块 B 通过 [register] 把 HTTP 厂商（OpenAI / MiniMax 等）接进来，
/// 切换厂商只需 [setType]，避免业务层直接 new 具体实现（降耦合）。
class TtsProviderFactory {
  TtsProviderFactory._();
  static final TtsProviderFactory instance = TtsProviderFactory._();

  TtsProviderType _type = TtsProviderType.system;
  TtsProviderType get type => _type;

  final Map<TtsProviderType, TtsProvider Function()> _builders = {
    TtsProviderType.system: () => SystemTtsProvider(),
  };

  /// 注册一个厂商的构建器（模块 B 用于接入 HTTP TTS）。
  void register(TtsProviderType type, TtsProvider Function() builder) {
    _builders[type] = builder;
  }

  /// 切换当前厂商类型（若未注册则回退到系统 TTS）。
  void setType(TtsProviderType type) => _type = type;

  /// 当前厂商对应的 Provider 实例。
  TtsProvider get current {
    final builder = _builders[_type] ?? _builders[TtsProviderType.system];
    return (builder ?? _builders.values.first)();
  }
}
