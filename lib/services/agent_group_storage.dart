import '../models/agent_group.dart';
import 'storage/app_database.dart';
import 'storage/cached_repository.dart';
import 'storage/sqlite_data_source.dart';

/// Agent 群存储：所有常驻群落盘
class AgentGroupStorage {
  AgentGroupStorage()
    : _repo = CachedRepository<AgentGroup>(
        dataSource: SqliteDataSource<AgentGroup>(
          table: 'agent_groups',
          db: AppDatabase.instance,
          toJson: (g) => g.toJson(),
          fromJson: (j) => AgentGroup.fromJson(j),
          idOf: (g) => g.id,
        ),
      );

  final CachedRepository<AgentGroup> _repo;

  Future<List<AgentGroup>> loadAll() async {
    final all = await _repo.loadAll();
    all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all;
  }

  Future<void> save(AgentGroup g) async {
    g.updatedAt = DateTime.now();
    await _repo.mutate((all) {
      final idx = all.indexWhere((x) => x.id == g.id);
      if (idx >= 0) {
        all[idx] = g;
      } else {
        all.insert(0, g);
      }
      all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  Future<void> delete(String id) async {
    await _repo.mutate((all) => all.removeWhere((g) => g.id == id));
  }

  AgentGroup? byId(String id) =>
      _repo.current.where((g) => g.id == id).firstOrNull;

  void clearCache() => _repo.clearCache();
}
