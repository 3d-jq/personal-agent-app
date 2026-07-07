import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/reminder.dart';
import 'log_service.dart';

class ReminderStorage extends ChangeNotifier {
  ReminderStorage();

  List<Reminder>? _cache;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/reminders.json');
  }

  Future<List<Reminder>> loadAll() async {
    if (_cache != null) return _cache!;
    try {
      final file = await _file();
      if (!await file.exists()) {
        _cache = [];
        return [];
      }
      final list = jsonDecode(await file.readAsString()) as List;
      _cache =
          list.map((j) => Reminder.fromJson(j as Map<String, dynamic>)).toList()
            ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      return _cache!;
    } catch (e) {
      log.e('ReminderStorage', '加载提醒数据失败（文件可能已损坏）: $e');
      await _backupCorruptedFile();
      _cache = [];
      return [];
    }
  }

  Future<void> _backupCorruptedFile() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final backup = File(
          '${file.path}.bak.${DateTime.now().millisecondsSinceEpoch}',
        );
        await file.rename(backup.path);
      }
    } catch (e) {
      log.e('ReminderStorage', '备份损坏文件失败: $e');
    }
  }

  Future<void> add(Reminder reminder) async {
    final all = await loadAll();
    all.insert(0, reminder);
    await _save(all);
  }

  Future<void> markCompleted(String id) async {
    final all = await loadAll();
    final idx = all.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      all[idx].isCompleted = true;
      await _save(all);
    }
  }

  Future<void> remove(String id) async {
    final all = await loadAll();
    all.removeWhere((r) => r.id == id);
    await _save(all);
  }

  Future<void> _save(List<Reminder> all) async {
    _cache = all;
    final file = await _file();
    await file.writeAsString(jsonEncode(all.map((e) => e.toJson()).toList()));
    notifyListeners();
  }
}
