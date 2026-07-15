import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'log_service.dart';

/// 主题服务（Claude Design System 版）。
///
/// 仅保留浅色 / 深色 / 跟随系统三种模式，并提供聊天气泡颜色自定义。
class ThemeService extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  Color? _userBubbleColor; // null = 使用主题色 nc.primary

  ThemeMode get mode => _mode;
  Color? get userBubbleColor => _userBubbleColor;

  ThemeService();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/theme.json');
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        final v = data['mode'] as String? ?? 'light';
        _mode = v == 'dark'
            ? ThemeMode.dark
            : v == 'system'
            ? ThemeMode.system
            : ThemeMode.light;
        final bubbleColorRaw = data['userBubbleColor'] as int?;
        _userBubbleColor = bubbleColorRaw != null ? Color(bubbleColorRaw) : null;
        notifyListeners();
      }
    } catch (e) {
      log.w('ThemeService', '加载主题失败: $e');
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    _save();
  }

  Future<void> setUserBubbleColor(Color? color) async {
    _userBubbleColor = color;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      final json = <String, dynamic>{
        'mode': _mode == ThemeMode.dark
            ? 'dark'
            : _mode == ThemeMode.system
            ? 'system'
            : 'light',
      };
      if (_userBubbleColor != null) {
        json['userBubbleColor'] = _userBubbleColor!.toARGB32();
      }
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      log.e('ThemeService', '保存主题失败: $e');
    }
  }

  String get label => _mode == ThemeMode.dark
      ? '深色'
      : _mode == ThemeMode.system
      ? '跟随系统'
      : '浅色';
}
