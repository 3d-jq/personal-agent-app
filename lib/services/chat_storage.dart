import '../models/chat_session.dart';
import 'storage/cached_repository.dart';
import 'storage/json_file_data_source.dart';

class ChatStorage {
  ChatStorage()
      : _repo = CachedRepository<ChatSession>(
          dataSource: JsonFileDataSource<ChatSession>(
            relativePath: 'sessions/index.json',
            fromJson: (list) => list
                .map((j) => ChatSession.fromJson(j as Map<String, dynamic>))
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
            toJson: (items) => items.map((s) => s.toJson()).toList(),
          ),
        );

  final CachedRepository<ChatSession> _repo;

  Future<List<ChatSession>> loadAll() => _repo.loadAll();

  Future<void> save(ChatSession session) async {
    await _repo.mutate((all) {
      final idx = all.indexWhere((s) => s.id == session.id);
      if (idx >= 0) {
        all[idx] = session;
      } else {
        all.insert(0, session);
      }
      all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  Future<void> delete(String id) async {
    await _repo.mutate((all) => all.removeWhere((s) => s.id == id));
  }

  void clearCache() => _repo.clearCache();
}
