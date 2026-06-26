import 'package:flutter/foundation.dart';

import '../models/note.dart';
import 'storage/cached_repository.dart';
import 'storage/json_file_data_source.dart';

class NoteStorage extends ChangeNotifier {
  NoteStorage()
    : _repo = CachedRepository<Note>(
        dataSource: JsonFileDataSource<Note>(
          relativePath: 'notes.json',
          fromJson: (list) {
            final notes = <Note>[];
            for (final item in list) {
              if (item is Map) {
                notes.add(Note.fromJson(Map<String, dynamic>.from(item)));
              }
            }
            notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            return notes;
          },
          toJson: (items) => items.map((e) => e.toJson()).toList(),
        ),
      ) {
    _repo.addListener(notifyListeners);
  }

  final CachedRepository<Note> _repo;

  Future<List<Note>> loadAll() => _repo.loadAll();

  /// 生成下一个简洁数字 ID。
  Future<String> nextId() async {
    final all = await loadAll();
    int max = 0;
    for (final n in all) {
      final v = int.tryParse(n.id);
      if (v != null && v > max) max = v;
    }
    return (max + 1).toString();
  }

  Future<void> add(Note note) async {
    await _repo.mutate((all) => all.insert(0, note));
  }

  Future<void> update(Note note) async {
    await _repo.mutate((all) {
      final idx = all.indexWhere((n) => n.id == note.id);
      if (idx >= 0) {
        note.updatedAt = DateTime.now();
        all[idx] = note;
      }
    });
  }

  Future<void> remove(String id) async {
    await _repo.mutate((all) => all.removeWhere((n) => n.id == id));
  }

  void clearCache() => _repo.clearCache();
}
