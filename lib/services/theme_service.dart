import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  String _bubbleColorKey = 'mint';

  ThemeMode get mode => _mode;
  String get bubbleColorKey => _bubbleColorKey;

  ThemeService();

  /// 预设气泡颜色：key → (light, dark)
  static const Map<String, (Color, Color)> bubbleColors = {
    'mint': (Color(0xFFD4EDE5), Color(0xFF2A4A42)),
    'blue': (Color(0xFFD4E5F7), Color(0xFF2A3A52)),
    'pink': (Color(0xFFF7D4E5), Color(0xFF522A3A)),
    'yellow': (Color(0xFFF7ECD4), Color(0xFF524A2A)),
    'purple': (Color(0xFFE5D4F7), Color(0xFF3A2A52)),
    'orange': (Color(0xFFF7DDD4), Color(0xFF523A2A)),
  };

  static const Map<String, String> bubbleColorLabels = {
    'mint': '薄荷',
    'blue': '天蓝',
    'pink': '樱花',
    'yellow': '暖阳',
    'purple': '薰衣草',
    'orange': '蜜柑',
  };

  (Color, Color) get bubbleColor =>
      bubbleColors[_bubbleColorKey] ?? bubbleColors['mint']!;

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
        _bubbleColorKey = data['bubbleColor'] as String? ?? 'mint';
        if (!bubbleColors.containsKey(_bubbleColorKey)) {
          _bubbleColorKey = 'mint';
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    _save();
  }

  Future<void> setBubbleColor(String key) async {
    if (!bubbleColors.containsKey(key)) return;
    _bubbleColorKey = key;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode({
          'mode': mode == ThemeMode.dark
              ? 'dark'
              : mode == ThemeMode.system
              ? 'system'
              : 'light',
          'bubbleColor': _bubbleColorKey,
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
