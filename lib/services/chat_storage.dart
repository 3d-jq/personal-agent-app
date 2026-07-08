import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/chat_session.dart';
import 'async_lock.dart';

/// 聊天记录存储。
///
/// - `sessions/index.json` 只保存会话元数据（id / title / updatedAt / type），
///   用于会话列表快速加载。
/// - `sessions/{id}.json` 保存单个会话的完整消息内容，按需读写，
///   避免会话增多后每次保存都重写整个索引文件。
class ChatStorage {
  ChatStorage() : _lock = AsyncLock();

  final AsyncLock _lock;

  List<ChatSession>? _indexCache;
  final _sessionCache = <String, ChatSession>{};

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/sessions');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _indexFile() async {
    final dir = await _dir();
    return File('${dir.path}/index.json');
  }

  Future<File> _sessionFile(String id) async {
    final dir = await _dir();
    return File('${dir.path}/$id.json');
  }

  /// 加载所有会话（含完整消息）。
  ///
  /// 仅用于切换会话等需要完整数据的场景；列表展示请优先用 [loadChatSessions]。
  Future<List<ChatSession>> loadAll() async {
    final index = await _loadIndex();
    final sessions = <ChatSession>[];
    for (final meta in index) {
      final session = await _loadSession(meta.id);
      if (session != null) {
        sessions.add(session);
      }
    }
    return sessions;
  }

  /// 只加载单聊会话元数据（排除 Agent 单聊）。
  ///
  /// 不读取消息内容，用于侧边栏会话列表。
  Future<List<ChatSession>> loadChatSessions() async {
    final index = await _loadIndex();
    return index.where((s) => s.type != 'agent').toList();
  }

  /// 加载指定会话的完整内容。
  Future<ChatSession?> loadSession(String id) => _loadSession(id);

  Future<ChatSession?> _loadSession(String id) async {
    final cached = _sessionCache[id];
    if (cached != null) return cached;

    final file = await _sessionFile(id);
    if (!await file.exists()) return null;

    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final session = ChatSession.fromJson(json);
      _sessionCache[id] = session;
      return session;
    } catch (e, stackTrace) {
      assert(() {
        // ignore: avoid_print
        print('ChatStorage loadSession error: $e\n$stackTrace');
        return true;
      }());
      return null;
    }
  }

  Future<List<ChatSession>> _loadIndex() async {
    final cached = _indexCache;
    if (cached != null) return List.unmodifiable(cached);

    final file = await _indexFile();
    if (!await file.exists()) {
      _indexCache = [];
      return [];
    }

    try {
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      final sessions = list
          .map((j) => ChatSession.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _indexCache = sessions;
      return List.unmodifiable(sessions);
    } catch (e, stackTrace) {
      assert(() {
        // ignore: avoid_print
        print('ChatStorage loadIndex error: $e\n$stackTrace');
        return true;
      }());
      _indexCache = [];
      return [];
    }
  }

  Future<void> _saveIndex(List<ChatSession> sessions) async {
    final file = await _indexFile();
    final metaList = sessions
        .map((s) => ChatSession(
              id: s.id,
              title: s.title,
              updatedAt: s.updatedAt,
              type: s.type,
            ).toJson())
        .toList();
    await file.writeAsString(jsonEncode(metaList));
    _indexCache = List.unmodifiable(sessions);
  }

  /// 保存会话：只写入对应 id 的会话文件，并增量更新索引。
  Future<void> save(ChatSession session) async {
    await _lock.run(() async {
      final file = await _sessionFile(session.id);
      await file.writeAsString(jsonEncode(session.toJson()));
      _sessionCache[session.id] = session;

      final index = List<ChatSession>.from(await _loadIndex());
      final idx = index.indexWhere((s) => s.id == session.id);
      if (idx >= 0) {
        index[idx] = ChatSession(
          id: session.id,
          title: session.title,
          updatedAt: session.updatedAt,
          type: session.type,
        );
      } else {
        index.insert(
          0,
          ChatSession(
            id: session.id,
            title: session.title,
            updatedAt: session.updatedAt,
            type: session.type,
          ),
        );
      }
      index.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await _saveIndex(index);
    });
  }

  /// 删除会话：删除会话文件和索引条目。
  Future<void> delete(String id) async {
    await _lock.run(() async {
      final file = await _sessionFile(id);
      if (await file.exists()) {
        await file.delete();
      }
      _sessionCache.remove(id);

      final index = List<ChatSession>.from(await _loadIndex())
        ..removeWhere((s) => s.id == id);
      await _saveIndex(index);
    });
  }

  /// 清空内存缓存，下次读取重新从磁盘加载。
  void clearCache() {
    _indexCache = null;
    _sessionCache.clear();
  }
}
