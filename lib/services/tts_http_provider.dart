import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'tts_provider.dart';
import '../services/tts_settings.dart';

/// HTTP 类 TTS 实现（OpenAI /audio/speech 兼容，MiniMax / SiliconFlow / 豆包等
/// 形式相近，可后续按厂商微调字段）。
///
/// 与系统 TTS 的差异：音频由厂商服务端合成后返回字节流，本地用 [just_audio]
/// 播放。因此不枚举设备语音，[voiceId] 由配置指定。
class HttpTtsProvider implements TtsProvider {
  HttpTtsProvider({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.voiceId = 'alloy',
    this.rate = 0.5,
    this.pitch = 1.0,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final String baseUrl;
  final String apiKey;
  final String model;
  final String voiceId;
  final double rate;
  final double pitch;
  final Dio _dio;

  AudioPlayer? _player;
  bool _speaking = false;
  final StreamController<bool> _speakingC =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get speakingChanges => _speakingC.stream;
  @override
  bool get isSpeaking => _speaking;

  void _setSpeaking(bool v) {
    _speaking = v;
    if (!_speakingC.isClosed) _speakingC.add(v);
  }

  /// 规范化 Base URL：仅去掉末尾多余斜杠，避免拼出 `//`。
  String _normalize(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// 音频合成端点（OpenAI 兼容）。
  String get endpoint => '${_normalize(baseUrl)}/audio/speech';

  /// 请求体（纯函数，便于单测字段与 speed 映射）。
  Map<String, dynamic> buildBody(String text) => {
    'model': model,
    'voice': voiceId,
    'input': text,
    'response_format': 'mp3',
    // OpenAI speed 合法范围 0.25 ~ 4.0；rate 归一化 0..1 直接用作 speed。
    'speed': rate.clamp(0.25, 4.0),
  };

  /// 请求音频字节（真实网络调用；单测聚焦 [buildBody]/[endpoint] 纯逻辑）。
  Future<Uint8List> fetchAudio(String text) async {
    final resp = await _dio.post(
      endpoint,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: buildBody(text),
    );
    final data = resp.data;
    if (data is List<int>) return Uint8List.fromList(data);
    throw Exception('音频响应格式异常');
  }

  @override
  Future<void> init() async {}

  @override
  Future<SpeakResult> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const SpeakResult(success: false, error: 'empty');
    }
    Uint8List bytes;
    try {
      bytes = await fetchAudio(trimmed);
    } catch (e) {
      return SpeakResult(success: false, error: 'fetch: ${e.toString()}');
    }
    try {
      _player ??= AudioPlayer();
      await _player!.setAudioSource(
        AudioSource.uri(
          Uri.dataFromBytes(bytes, mimeType: 'audio/mpeg'),
        ),
      );
      await _player!.play();
      _setSpeaking(true);
      // 监听播放完成，自动复位状态。
      _player!.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          _setSpeaking(false);
        }
      });
      return const SpeakResult(success: true);
    } catch (e) {
      return SpeakResult(success: false, error: 'play: ${e.toString()}');
    }
  }

  @override
  Future<void> stop() async {
    _setSpeaking(false);
    await _player?.stop();
  }

  @override
  Future<List<TtsVoice>> availableVoices() async => const [];

  @override
  void setSelectedVoice(Map<String, String>? voice) {}

  @override
  void setRate(double r) {
    // HTTP 厂商的语速在下一次 speak 时经 speed 生效。
  }

  @override
  void setPitch(double p) {}

  @override
  void dispose() {
    _player?.dispose();
    if (!_speakingC.isClosed) _speakingC.close();
  }
}
