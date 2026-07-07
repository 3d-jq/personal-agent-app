import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'log_service.dart';

/// 主题服务（Claude Design System 版）。
///
/// 仅保留浅色 / 深色 / 跟随系统三种模式，不再提供多主题预设或气泡颜色切换。
class ThemeService extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;

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

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode({
          'mode': _mode == ThemeMode.dark
              ? 'dark'
              : _mode == ThemeMode.system
              ? 'system'
              : 'light',
        }),
      );
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
