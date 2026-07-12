import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'tts_provider.dart';
import 'tts_http_provider.dart';
import 'tts_service.dart';
import 'log_service.dart';

/// 语音服务配置：多厂商（系统 / OpenAI / MiniMax / SiliconFlow / 豆包等）。
///
/// 持久化到本地 JSON；[apply] 时把当前配置接线到 [TtsProviderFactory]，
/// 并通知 [TtsService] 重建底层 Provider。UI 只依赖 [TtsService] 稳定门面，
/// 不感知具体厂商，从而降耦合。
class TtsServiceConfig extends ChangeNotifier {
  TtsServiceConfig._();
  static final TtsServiceConfig instance = TtsServiceConfig._();

  TtsProviderType _type = TtsProviderType.system;
  TtsProviderType get type => _type;

  /// HTTP 类厂商的连接参数。
  String baseUrl = '';
  String apiKey = '';
  String model = '';
  String voiceId = '';

  /// 语速 / 音调（归一化 0..1，默认 0.5 / 1.0）。
  double rate = 0.5;
  double pitch = 1.0;

  bool _loaded = false;

  /// 仅供测试：清空内存状态（不删文件），便于用例间隔离。
  void resetForTest() {
    _type = TtsProviderType.system;
    baseUrl = '';
    apiKey = '';
    model = '';
    voiceId = '';
    rate = 0.5;
    pitch = 1.0;
    _loaded = false;
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await _file();
      if (await f.exists()) {
        final d = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final t = d['type'];
        if (t is String) {
          _type = TtsProviderType.values.firstWhere(
            (e) => e.name == t,
            orElse: () => TtsProviderType.system,
          );
        }
        baseUrl = d['baseUrl'] ?? '';
        apiKey = d['apiKey'] ?? '';
        model = d['model'] ?? '';
        voiceId = d['voiceId'] ?? '';
        rate = (d['rate'] as num?)?.toDouble() ?? 0.5;
        pitch = (d['pitch'] as num?)?.toDouble() ?? 1.0;
      }
    } catch (e) {
      log.w('TtsServiceConfig', '加载语音服务配置失败: $e');
    }
    _loaded = true;
  }

  /// 同步切换当前厂商（仅改内存状态 + 接线工厂，不落盘）。
  ///
  /// 用于设置页分段点击的即时反馈：在 [onSelectionChanged] 中同步调用，
  /// 工厂立即切到目标厂商、UI 同时重建，无需等待文件 I/O；落盘交由
  /// [setType] 在后台完成（[wire] 幂等，重复调用安全）。
  void selectType(TtsProviderType t) {
    _type = t;
    wire();
  }

  /// 切换厂商类型并立即接线工厂（异步：含持久化）。
  Future<void> setType(TtsProviderType t) async {
    _type = t;
    await apply();
  }

  /// 保存配置 + 接线 [TtsProviderFactory]，使 [TtsService] 切到当前厂商。
  Future<void> apply() async {
    await _save();
    wire();
  }

  /// 仅接线工厂（不落盘）：供 [load] 后或 [apply] 复用。
  void wire() {
    if (_type == TtsProviderType.system) {
      TtsProviderFactory.instance.setType(TtsProviderType.system);
    } else {
      TtsProviderFactory.instance.register(
        _type,
        () => HttpTtsProvider(
          baseUrl: baseUrl,
          apiKey: apiKey,
          model: model,
          voiceId: voiceId.isEmpty ? _defaultVoice(_type) : voiceId,
          rate: rate,
          pitch: pitch,
        ),
      );
      TtsProviderFactory.instance.setType(_type);
    }
    // 通知 TtsService 单例重建底层 Provider（保持对外门面不变）。
    TtsService().reloadProvider();
  }

  String _defaultVoice(TtsProviderType t) {
    switch (t) {
      case TtsProviderType.openai:
        return 'alloy';
      case TtsProviderType.minimax:
        return 'male-qn-qingse';
      case TtsProviderType.siliconflow:
        return 'Speech-01';
      case TtsProviderType.doubao:
        return 'zh_female_qingxin';
      default:
        return '';
    }
  }

  Future<File> _file() async {
    final d = await getApplicationDocumentsDirectory();
    return File('${d.path}/tts_service_config.json');
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({
        'type': _type.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'voiceId': voiceId,
        'rate': rate,
        'pitch': pitch,
      }));
    } catch (e) {
      log.w('TtsServiceConfig', '保存语音服务配置失败: $e');
    }
    notifyListeners();
  }
}
