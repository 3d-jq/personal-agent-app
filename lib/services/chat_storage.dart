import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/chat_session.dart';
import 'async_lock.dart';
import 'storage/app_database.dart';

/// 聊天记录存储，基于 SQLite。
///
/// 所有会话存储在 `chat_sessions` 表中，通过 [AppDatabase] 读写。
/// 保留内存缓存层和并发锁，API 不变。
class ChatStorage {
  ChatStorage() : _lock = AsyncLock();

  final AsyncLock _lock;
  final _db = AppDatabase.instance;
  final _sessionCache = <String, ChatSession>{};

  /// 加载所有会话（含完整消息）。
  Future<List<ChatSession>> loadAll() async {
    final rows = await _db.db.query('chat_sessions', columns: ['data']);
    final sessions = rows.map((r) {
      final map = jsonDecode(r['data'] as String) as Map<String, dynamic>;
      return ChatSession.fromJson(map);
    }).toList();
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  /// 只加载单聊会话元数据（排除 Agent 单聊）。
  Future<List<ChatSession>> loadChatSessions() async {
    final all = await loadAll();
    return all.where((s) => s.type != 'agent').toList();
  }

  /// 加载指定会话的完整内容。
  Future<ChatSession?> loadSession(String id) async {
    final cached = _sessionCache[id];
    if (cached != null) return cached;

    final rows = await _db.db.query(
      'chat_sessions',
      columns: ['data'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final map = jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
    final session = ChatSession.fromJson(map);
    _sessionCache[id] = session;
    return session;
  }

  /// 保存会话：upsert 到 SQLite + 更新内存缓存。
  Future<void> save(ChatSession session) async {
    await _lock.run(() async {
      await _db.db.insert(
        'chat_sessions',
        {
          'id': session.id,
          'data': jsonEncode(session.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _sessionCache[session.id] = session;
    });
  }

  /// 删除会话。
  Future<void> delete(String id) async {
    await _lock.run(() async {
      await _db.deleteById(table: 'chat_sessions', id: id);
      _sessionCache.remove(id);
    });
  }

  /// 清空内存缓存。
  void clearCache() {
    _sessionCache.clear();
  }
}
