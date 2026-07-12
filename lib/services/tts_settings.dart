import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'log_service.dart';

/// 一条可用的 TTS 语音（来自 flutter_tts 的 getVoices）。
class TtsVoice {
  const TtsVoice({required this.name, required this.locale});
  final String name;
  final String locale;

  /// 是否看起来像中文语音（用于 UI 高亮/分组）。
  bool get isChinese =>
      locale.toLowerCase().startsWith('zh') ||
      name.toLowerCase().contains('chinese') ||
      name.toLowerCase().contains('普通话') ||
      name.toLowerCase().contains('mandarin') ||
      name.toLowerCase().contains('中文');

  @override
  String toString() => '$name ($locale)';
}

/// TTS 设置：记录用户选定的朗读语音（持久化到本地 JSON）。
///
/// 注意：Android 不允许第三方 App 直接下载安装 TTS 语音数据包，语音包由系统
/// 「文字转语音(TTS)输出」设置（即 Google TTS 引擎）管理。本设置页只负责
/// 「在本机已有语音中选择」+ 一键跳转系统语音设置去安装，无法在 App 内直接安装。
class TtsSettings extends ChangeNotifier {
  static final TtsSettings _instance = TtsSettings._();
  factory TtsSettings() => _instance;
  TtsSettings._();

  /// 用户选定的语音（flutter_tts setVoice 所需：name + locale），null 表示用默认语言回退。
  Map<String, String>? _selectedVoice;
  Map<String, String>? get selectedVoice => _selectedVoice;
  String? get selectedVoiceName => _selectedVoice?['name'];

  bool _loaded = false;

  /// 仅供测试：清空内存状态（不删文件），便于用例间隔离。
  void resetForTest() {
    _selectedVoice = null;
    _loaded = false;
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await _file();
      if (await f.exists()) {
        final d = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final v = d['selectedVoice'];
        if (v is Map) {
          final name = v['name']?.toString() ?? '';
          final locale = v['locale']?.toString() ?? '';
          _selectedVoice = name.isEmpty ? null : {'name': name, 'locale': locale};
        }
      }
    } catch (e) {
      log.w('TtsSettings', '加载TTS设置失败: $e');
    }
    _loaded = true;
  }

  /// 选择语音（voice 为 null 表示清除选择、回退到默认语言）。
  Future<void> selectVoice(Map<String, String>? voice) async {
    _selectedVoice =
        voice == null ? null : {'name': voice['name'] ?? '', 'locale': voice['locale'] ?? ''};
    if (_selectedVoice != null && _selectedVoice!['name']!.isEmpty) _selectedVoice = null;
    notifyListeners();
    await _save();
  }

  Future<File> _file() async {
    final d = await getApplicationDocumentsDirectory();
    return File('${d.path}/tts_settings.json');
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({'selectedVoice': _selectedVoice}));
    } catch (e) {
      log.w('TtsSettings', '保存TTS设置失败: $e');
    }
  }
}

/// 打开系统「文字转语音(TTS)输出」设置，让用户在系统里安装/选择语音包。
/// 返回是否成功唤起（失败通常因设备无该设置入口）。
Future<bool> openSystemTtsSettings() async {
  try {
    await const MethodChannel('com.example/open_tts_settings').invokeMethod('open');
    return true;
  } catch (e) {
    log.w('TtsSettings', '打开系统TTS设置失败: $e');
    return false;
  }
}
