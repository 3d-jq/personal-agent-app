import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/chat_session.dart';
import 'async_lock.dart';

class ChatStorage {
  static final ChatStorage _instance = ChatStorage._();
  factory ChatStorage() => _instance;
  ChatStorage._();

  final _lock = AsyncLock();
  List<ChatSession>? _cache;

  Future<File> _dir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/sessions');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/index.json');
  }

  Future<List<ChatSession>> loadAll() async {
    if (_cache != null) return _cache!;
    try {
      final file = await _dir();
      if (!await file.exists()) {
        _cache = [];
        return _cache!;
      }
      final list = jsonDecode(await file.readAsString()) as List;
      _cache = list.map((j) => ChatSession.fromJson(j as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return _cache!;
    } catch (_) {
      await _backupCorruptedFile();
      _cache = [];
      return _cache!;
    }
  }

  Future<void> _backupCorruptedFile() async {
    try {
      final file = await _dir();
      if (await file.exists()) {
        final backup = File('${file.path}.bak.${DateTime.now().millisecondsSinceEpoch}');
        await file.rename(backup.path);
      }
    } catch (_) {}
  }

  Future<void> save(ChatSession session) async {
    await _lock.run(() async {
      final all = await loadAll();
      final idx = all.indexWhere((s) => s.id == session.id);
      if (idx >= 0) {
        all[idx] = session;
      } else {
        all.insert(0, session);
      }
      all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _cache = all;
      final file = await _dir();
      await file.writeAsString(jsonEncode(all.map((s) => s.toJson()).toList()));
    });
  }

  Future<void> delete(String id) async {
    await _lock.run(() async {
      final all = await loadAll();
      all.removeWhere((s) => s.id == id);
      _cache = all;
      final file = await _dir();
      await file.writeAsString(jsonEncode(all.map((s) => s.toJson()).toList()));
    });
  }

  void clearCache() => _cache = null;
}
