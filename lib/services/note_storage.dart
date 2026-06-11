import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';

class NoteStorage {
  static final NoteStorage _instance = NoteStorage._();
  factory NoteStorage() => _instance;
  NoteStorage._();

  List<Note>? _cache;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/notes.json');
  }

  Future<List<Note>> loadAll() async {
    if (_cache != null) return _cache!;
    try {
      final file = await _file();
      if (!await file.exists()) {
        _cache = [];
        return [];
      }
      final list = jsonDecode(await file.readAsString()) as List;
      _cache = list.map((j) => Note.fromJson(j as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return _cache!;
    } catch (_) {
      _cache = [];
      return [];
    }
  }

  Future<void> add(Note note) async {
    final all = await loadAll();
    all.insert(0, note);
    await _save(all);
  }

  Future<void> update(Note note) async {
    final all = await loadAll();
    final idx = all.indexWhere((n) => n.id == note.id);
    if (idx >= 0) {
      note.updatedAt = DateTime.now();
      all[idx] = note;
      await _save(all);
    }
  }

  Future<void> remove(String id) async {
    final all = await loadAll();
    all.removeWhere((n) => n.id == id);
    await _save(all);
  }

  Future<void> _save(List<Note> all) async {
    _cache = all;
    final file = await _file();
    await file.writeAsString(jsonEncode(all.map((e) => e.toJson()).toList()));
  }
}
