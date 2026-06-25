import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  String _bubbleColorKey = 'mint';
  String _themeKey = 'neutral';

  ThemeMode get mode => _mode;
  String get bubbleColorKey => _bubbleColorKey;
  String get themeKey => _themeKey;

  Color get seedColor => _themes[_themeKey]?.color ?? _themes['neutral']!.color;

  ThemeService();

  /// 预设主题
  static const Map<String, _ThemePreset> _themes = {
    'teal': _ThemePreset(Color(0xFF009688), '青绿'),
    'ocean': _ThemePreset(Color(0xFF1565C0), '海蓝'),
    'lavender': _ThemePreset(Color(0xFF6750A4), '薰衣草'),
    'rose': _ThemePreset(Color(0xFFC2185B), '玫瑰'),
    'neutral': _ThemePreset(Color(0xFF607D8B), '素白'),
  };

  List<String> get themeKeys => _themes.keys.toList();

  String themeLabel(String key) => _themes[key]?.label ?? key;

  Color themeColor(String key) => _themes[key]?.color ?? _themes['teal']!.color;

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
        _themeKey = data['theme'] as String? ?? 'neutral';
        if (!_themes.containsKey(_themeKey)) {
          _themeKey = 'teal';
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

  Future<void> setTheme(String key) async {
    if (!_themes.containsKey(key)) return;
    _themeKey = key;
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
          'mode': _mode == ThemeMode.dark
              ? 'dark'
              : _mode == ThemeMode.system
              ? 'system'
              : 'light',
          'bubbleColor': _bubbleColorKey,
          'theme': _themeKey,
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

class _ThemePreset {
  final Color color;
  final String label;
  const _ThemePreset(this.color, this.label);
}
