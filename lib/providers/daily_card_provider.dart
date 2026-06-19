import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import '../services/ai_service.dart';
import '../services/chat_stream_event.dart';
import '../services/crypto_util.dart';
import '../services/memory_storage.dart';
import '../tools/calendar_tool.dart';
import '../tools/weather_tool.dart';

class DailyCardProvider extends ChangeNotifier {
  String? _greeting;
  bool _loading = false;

  String? get greeting => _greeting;
  bool get loading => _loading;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/daily_card.json');
  }

  Future<bool> shouldShowToday() async {
    try {
      final file = await _file();
      if (!await file.exists()) return true;
      final data = jsonDecode(await file.readAsString()) as Map;
      final lastDate = data['date'] as String?;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      return lastDate != today;
    } catch (_) {
      return true;
    }
  }

  Future<void> loadCached() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        _greeting = data['greeting'] as String?;
      }
    } catch (_) {}
  }

  Future<void> generate() async {
    _loading = true;
    notifyListeners();

    final buf = StringBuffer();
    final h = DateTime.now().hour;
    final t = h < 6 ? '凌晨' : h < 9 ? '早上' : h < 12 ? '上午' : h < 14 ? '中午' : h < 18 ? '下午' : h < 21 ? '晚上' : '深夜';
    buf.writeln('现在是$t。');

    try { final w = WeatherTool()..apiKey = CryptoUtil.decrypt(dotenv.env['GAODE_API_KEY'] ?? ''); buf.writeln('天气: ${await w.execute({'city': '北京', 'units': 'metric'})}'); } catch (_) {}
    try { final n = DateTime.now(); final c = CalendarTool(); buf.writeln('日程: ${await c.execute({'action': 'query', 'start_ms': n.millisecondsSinceEpoch, 'end_ms': n.add(const Duration(days: 1)).millisecondsSinceEpoch})}'); } catch (_) {}
    try { final m = MemoryStorage(); await m.loadAll(); final f = m.memoryContext; if (f.isNotEmpty) buf.writeln('记忆: $f'); } catch (_) {}

    final ctx = buf.toString();
    if (!ctx.contains('天气') && !ctx.contains('日程') && !ctx.contains('记忆')) {
      _greeting = '${t}好！新的一天 ✨';
    } else {
      try {
        final ai = AIService(baseUrl: 'https://apihub.agnes-ai.com/v1', apiKey: CryptoUtil.decrypt(dotenv.env['AGNES_API_KEY'] ?? ''), providerName: '', model: 'agnes-2.0-flash');
        final stream = ai.sendMessageStream([{'role': 'user', 'content': '根据以下信息，生成一段温暖自然的问候（不超过60字），像朋友聊天一样，自然融入信息，不要罗列。\n$ctx\n输出:'}]);
        final r = StringBuffer();
        await for (final event in stream) {
          if (event is TextChunkEvent) r.write(event.text);
        }
        _greeting = r.toString().trim();
      } catch (_) {}
      _greeting ??= '${t}好！新的一天 ✨';
    }

    await _cache();
    _loading = false;
    notifyListeners();
  }

  Future<void> _cache() async {
    final file = await _file();
    await file.writeAsString(jsonEncode({
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'greeting': _greeting ?? '',
    }));
  }
}
