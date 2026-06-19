import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';

class NoteStorage extends ChangeNotifier {
  static final NoteStorage _instance = NoteStorage._();
  factory NoteStorage() => _instance;
  NoteStorage._();

  List<Note>? _cache;
  Future<List<Note>>? _loading;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/notes.json');
  }

  Future<List<Note>> loadAll() async {
    if (_cache != null) return List<Note>.from(_cache!);
    if (_loading != null) return await _loading!;
    _loading = _doLoad();
    try {
      return await _loading!;
    } finally {
      _loading = null;
    }
  }

  Future<List<Note>> _doLoad() async {
    List<Note>? loaded;
    try {
      final file = await _file();
      if (await file.exists()) {
        final list = jsonDecode(await file.readAsString()) as List;
        loaded = list.map((j) => Note.fromJson(j as Map<String, dynamic>)).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
    } catch (_) {
      await _backupCorruptedFile();
    }
    if (_cache == null) _cache = loaded ?? [];
    return List<Note>.from(_cache!);
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
    for (final n in all) {
      final v = int.tryParse(n.id);
      if (v != null && v > max) max = v;
    }
    return (max + 1).toString();
  }

  Future<void> add(Note note) async {
    final all = List<Note>.from(await loadAll());
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
    notifyListeners();
  }
}
