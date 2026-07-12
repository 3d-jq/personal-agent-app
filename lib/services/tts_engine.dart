import 'package:flutter_tts/flutter_tts.dart';

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
