import '../models/agent_group.dart';
import 'storage/cached_repository.dart';
import 'storage/json_file_data_source.dart';

/// Agent 群存储：所有常驻群落盘
class AgentGroupStorage {
  AgentGroupStorage()
    : _repo = CachedRepository<AgentGroup>(
        dataSource: JsonFileDataSource<AgentGroup>(
          relativePath: 'agent_groups.json',
          fromJson: (list) =>
              list
                  .map((j) => AgentGroup.fromJson(j as Map<String, dynamic>))
                  .toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
          toJson: (items) => items.map((e) => e.toJson()).toList(),
        ),
      );

  final CachedRepository<AgentGroup> _repo;

  Future<List<AgentGroup>> loadAll() => _repo.loadAll();

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
