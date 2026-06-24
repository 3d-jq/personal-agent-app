import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/agent_group.dart';
import 'async_lock.dart';

/// Agent 群存储：所有常驻群落盘
class AgentGroupStorage {
  AgentGroupStorage();

  final _lock = AsyncLock();
  List<AgentGroup>? _cache;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/agent_groups.json');
  }

  Future<List<AgentGroup>> loadAll() async {
    if (_cache != null) return _cache!;
    try {
      final file = await _file();
      if (!await file.exists()) {
        _cache = [];
        return _cache!;
      }
      final list = jsonDecode(await file.readAsString()) as List;
      _cache = list
          .map((j) => AgentGroup.fromJson(j as Map<String, dynamic>))
          .toList()
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
      final file = await _file();
      if (await file.exists()) {
        final backup = File(
            '${file.path}.bak.${DateTime.now().millisecondsSinceEpoch}');
        await file.rename(backup.path);
      }
    } catch (_) {}
  }

  Future<void> save(AgentGroup g) async {
    await _lock.run(() async {
      final all = await loadAll();
      g.updatedAt = DateTime.now();
      final idx = all.indexWhere((x) => x.id == g.id);
      if (idx >= 0) {
        all[idx] = g;
      } else {
        all.insert(0, g);
      }
      all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _cache = all;
      final file = await _file();
      await file.writeAsString(
          jsonEncode(all.map((e) => e.toJson()).toList()));
    });
  }

  Future<void> delete(String id) async {
    await _lock.run(() async {
      final all = await loadAll();
      all.removeWhere((g) => g.id == id);
      _cache = all;
      final file = await _file();
      await file.writeAsString(
          jsonEncode(all.map((e) => e.toJson()).toList()));
    });
  }

  AgentGroup? byId(String id) =>
      (_cache ?? const []).where((g) => g.id == id).firstOrNull;

  void clearCache() => _cache = null;
}
