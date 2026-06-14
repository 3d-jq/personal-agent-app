import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PersonalizationStorage {
  static final PersonalizationStorage _instance = PersonalizationStorage._();
  factory PersonalizationStorage() => _instance;
  PersonalizationStorage._();

  String userName = 'Ren da';
  String aiStyle = '默认';
  String customPrompt = '';
  bool _loaded = false;

  static const _aiStyles = ['默认', '简洁', '详细', '幽默', '专业'];

  List<String> get availableStyles => _aiStyles;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/personalization.json');
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final file = await _file();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        userName = data['userName'] as String? ?? 'Ren da';
        aiStyle = data['aiStyle'] as String? ?? '默认';
        customPrompt = data['customPrompt'] as String? ?? '';
      }
    } catch (_) {
      await _backupCorruptedFile();
    }
    _loaded = true;
  }

  Future<void> _backupCorruptedFile() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final backup = File('${file.path}.bak.${DateTime.now().millisecondsSinceEpoch}');
        await file.rename(backup.path);
      }
    } catch (_) {}
  }

  Future<void> save() async {
    final file = await _file();
    await file.writeAsString(jsonEncode({
      'userName': userName,
      'aiStyle': aiStyle,
      'customPrompt': customPrompt,
    }));
  }

  String get stylePrompt {
    switch (aiStyle) {
      case '简洁': return '请用简短精炼的方式回复。';
      case '详细': return '请提供详细、全面的解释和回答。';
      case '幽默': return '请用轻松幽默的风格回复，适当使用比喻和有趣的表达。';
      case '专业': return '请用专业严谨的风格回复，使用专业术语。';
      default: return '';
    }
  }
}
