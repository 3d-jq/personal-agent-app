import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/memory_entry.dart';

class MemoryStorage extends ChangeNotifier {
  static final MemoryStorage _instance = MemoryStorage._();
  factory MemoryStorage() => _instance;
  MemoryStorage._();

  List<MemoryEntry>? _cache;
  Future<List<MemoryEntry>>? _loading;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/memories.json');
  }

  Future<List<MemoryEntry>> loadAll() async {
    if (_cache != null) return List<MemoryEntry>.from(_cache!);
    if (_loading != null) return await _loading!;
    _loading = _doLoad();
    try {
      return await _loading!;
    } finally {
      _loading = null;
    }
  }

  Future<List<MemoryEntry>> _doLoad() async {
    List<MemoryEntry>? loaded;
    try {
      final file = await _file();
      if (await file.exists()) {
        final list = jsonDecode(await file.readAsString()) as List;
        loaded = list.map((j) => MemoryEntry.fromJson(j as Map<String, dynamic>)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (_) {
      await _backupCorruptedFile();
    }
    if (_cache == null) _cache = loaded ?? [];
    return List<MemoryEntry>.from(_cache!);
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

  /// 生成下一个简洁数字 ID。
  Future<String> nextId() async {
    final all = await loadAll();
    int max = 0;
    for (final e in all) {
      final n = int.tryParse(e.id);
      if (n != null && n > max) max = n;
    }
    return (max + 1).toString();
  }

  Future<void> add(MemoryEntry entry) async {
    final all = List<MemoryEntry>.from(await loadAll());
    all.insert(0, entry);
    await _save(all);
    if (kDebugMode) {
      debugPrint('[MemoryStorage] add: total=${all.length}, file=${(await _file()).path}');
    }
  }

  Future<void> update(MemoryEntry entry) async {
    final all = List<MemoryEntry>.from(await loadAll());
    final idx = all.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      all[idx] = entry;
      await _save(all);
    }
  }

  Future<void> remove(String id) async {
    final all = List<MemoryEntry>.from(await loadAll());
    all.removeWhere((e) => e.id == id);
    await _save(all);
  }

  Future<void> _save(List<MemoryEntry> all) async {
    _cache = all;
    final file = await _file();
    await file.writeAsString(jsonEncode(all.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  String get preferencePrompt {
    final prefs = _cache?.where((e) => e.type == MemoryType.preference).toList() ?? [];
    if (prefs.isEmpty) return '';
    return prefs.map((e) => '- ${e.content}').join('\n');
  }

  String get memoryContext {
    final facts = _cache?.where((e) => e.type == MemoryType.fact).take(10).toList() ?? [];
    if (facts.isEmpty) return '';
    return facts.map((e) => '- ${e.content}').join('\n');
  }

  /// 暴露缓存的记忆列表（已加载后可用）
  List<MemoryEntry> get cachedEntries => _cache ?? [];

  /// 筛选与用户消息相关的事实记忆
  List<MemoryEntry> relevantFacts(String userMessage) {
    final facts = (_cache ?? []).where((e) => e.type == MemoryType.fact).toList();
    if (facts.isEmpty) return [];
    if (userMessage.isEmpty) return facts.take(3).toList();

    final msgLower = userMessage.toLowerCase();
    final scored = <MapEntry<int, MemoryEntry>>[];

    for (final fact in facts) {
      final content = fact.content.toLowerCase();
      int score = 0;
      final words = content.split(RegExp(r'[\s,，。.、；;：:!?！？]+'));
      for (final word in words) {
        if (word.length >= 2 && msgLower.contains(word)) {
          score += word.length;
        }
      }
      if (score > 0) scored.add(MapEntry(score, fact));
    }

    scored.sort((a, b) => b.key.compareTo(a.key));
    final result = scored.take(5).map((e) => e.value).toList();
    return result.isEmpty ? facts.take(3).toList() : result;
  }

  /// 所有偏好记忆
  List<MemoryEntry> get cachedPreferences =>
      (_cache ?? []).where((e) => e.type == MemoryType.preference).toList();
}
