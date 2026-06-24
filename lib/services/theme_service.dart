import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode({
          'mode': mode == ThemeMode.dark
              ? 'dark'
              : mode == ThemeMode.system
              ? 'system'
              : 'light',
        }),
      );
    } catch (_) {}
  }

  String get label => _mode == ThemeMode.dark
      ? '深色'
      : _mode == ThemeMode.system
      ? '跟随系统'
      : '浅色';
}
