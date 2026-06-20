import 'package:flutter/foundation.dart';

import '../models/memory_entry.dart';
import 'storage/cached_repository.dart';
import 'storage/json_file_data_source.dart';

class MemoryStorage extends ChangeNotifier {
  static final MemoryStorage _instance = MemoryStorage._();
  factory MemoryStorage() => _instance;
  MemoryStorage._()
      : _repo = CachedRepository<MemoryEntry>(
          dataSource: JsonFileDataSource<MemoryEntry>(
            relativePath: 'memories.json',
            fromJson: (list) => list
                .map((j) => MemoryEntry.fromJson(j as Map<String, dynamic>))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
            toJson: (items) => items.map((e) => e.toJson()).toList(),
          ),
        ) {
    _repo.addListener(notifyListeners);
  }

  final CachedRepository<MemoryEntry> _repo;

  Future<List<MemoryEntry>> loadAll() => _repo.loadAll();

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
    await _repo.mutate((all) => all.insert(0, entry));
    if (kDebugMode) {
      debugPrint('[MemoryStorage] add: total=${_repo.current.length}');
    }
  }

  Future<void> update(MemoryEntry entry) async {
    await _repo.mutate((all) {
      final idx = all.indexWhere((e) => e.id == entry.id);
      if (idx >= 0) all[idx] = entry;
    });
  }

  Future<void> remove(String id) async {
    await _repo.mutate((all) => all.removeWhere((e) => e.id == id));
  }

  String get preferencePrompt {
    final prefs = _repo.current.where((e) => e.type == MemoryType.preference).toList();
    if (prefs.isEmpty) return '';
    return prefs.map((e) => '- ${e.content}').join('\n');
  }

  String get memoryContext {
    final facts = _repo.current.where((e) => e.type == MemoryType.fact).take(10).toList();
    if (facts.isEmpty) return '';
    return facts.map((e) => '- ${e.content}').join('\n');
  }

  /// 暴露缓存的记忆列表（已加载后可用）
  List<MemoryEntry> get cachedEntries => _repo.current;

  /// 筛选与用户消息相关的事实记忆
  List<MemoryEntry> relevantFacts(String userMessage) {
    final facts = _repo.current.where((e) => e.type == MemoryType.fact).toList();
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
      _repo.current.where((e) => e.type == MemoryType.preference).toList();
}
