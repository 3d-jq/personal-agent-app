import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import 'async_lock.dart';
import 'storage/app_database.dart';

/// 聊天记录存储，基于 SQLite。
///
/// 设计（微信级分层）：
/// - `chat_sessions` 表只存**会话元数据**（id/title/createdAt/updatedAt/type +
///   preview/messageCount），列表/搜索读取极轻量，不再反序列化整包历史。
/// - `messages` 表存**每条消息独立一行**（session_id, msg_id, seq, data），
///   支持游标分页。打开会话默认只取最近 [defaultWindow] 条（内存窗口），
///   上滑再分页加载更早消息，彻底消除「进聊天页就加载全量」的卡顿。
/// - 保存时增量 upsert（按 msg_id 覆盖、绝不 DELETE 其他消息），窗口之外的
///   历史始终安全保留在表中。
class ChatStorage {
  ChatStorage() : _lock = AsyncLock();

  final AsyncLock _lock;
  final _db = AppDatabase.instance;
  final _sessionCache = <String, ChatSession>{};

  /// 打开会话时内存中保留的最近消息条数（滑动窗口）。
  static const int defaultWindow = 200;

  /// 加载所有会话元数据（不含消息体）。按 updatedAt 倒序。
  /// 支持 [offset]/[limit] 分页，典型侧边栏无限滚动场景。
  Future<List<ChatSession>> loadAll({int? offset, int? limit}) async {
    final rows = await _db.db.query('chat_sessions', columns: ['data']);
    final sessions = rows.map((r) {
      final map = jsonDecode(r['data'] as String) as Map<String, dynamic>;
      return ChatSession.fromJson(map);
    }).toList();
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (offset != null && offset > 0) {
      return sessions.skip(offset).take(limit ?? sessions.length).toList();
    }
    if (limit != null) {
      return sessions.take(limit).toList();
    }
    return sessions;
  }

  /// 只加载单聊会话元数据（排除 Agent 单聊）。
  Future<List<ChatSession>> loadChatSessions({int? offset, int? limit}) async {
    final all = await loadAll();
    final filtered = all.where((s) => s.type != 'agent').toList();
    if (offset != null && offset > 0) {
      return filtered.skip(offset).take(limit ?? filtered.length).toList();
    }
    if (limit != null) {
      return filtered.take(limit).toList();
    }
    return filtered;
  }

  /// 加载指定会话。
  ///
  /// - 不传 [limit]/[beforeSeq]：取最近 [defaultWindow] 条（内存窗口），并写入缓存。
  /// - 传 [limit]+[beforeSeq]：游标分页取更早的消息（上滑加载），不写缓存。
  /// - [full]=true：加载该会话全部消息（导出用），忽略窗口。
  Future<ChatSession?> loadSession(
    String id, {
    int? limit,
    int? beforeSeq,
    int? afterSeq,
    bool full = false,
  }) async {
    final cached = _sessionCache[id];
    if (cached != null && limit == null && beforeSeq == null && afterSeq == null && !full) {
      return cached;
    }

    final metaRows = await _db.db.query(
      'chat_sessions',
      columns: ['data'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (metaRows.isEmpty) return null;
    final meta =
        ChatSession.fromJson(jsonDecode(metaRows.first['data'] as String)
            as Map<String, dynamic>);

    final msgs = await _loadMessages(
      id,
      limit: full ? null : (limit ?? defaultWindow),
      beforeSeq: beforeSeq,
      afterSeq: afterSeq,
    );

    final session = ChatSession(
      id: id,
      title: meta.title,
      type: meta.type,
      createdAt: meta.createdAt,
      updatedAt: meta.updatedAt,
      messages: msgs,
    );
    if (limit == null && beforeSeq == null && afterSeq == null && !full) {
      _sessionCache[id] = session;
    }
    return session;
  }

  /// 从 messages 表按 (session_id, seq) 游标分页读取，返回时间正序列表。
  Future<List<ChatMessage>> _loadMessages(
    String sessionId, {
    required int? limit,
    int? beforeSeq,
    int? afterSeq,
  }) async {
    String where;
    List<dynamic> whereArgs;

    if (beforeSeq != null) {
      where = 'session_id = ? AND seq < ?';
      whereArgs = [sessionId, beforeSeq];
    } else if (afterSeq != null) {
      where = 'session_id = ? AND seq > ?';
      whereArgs = [sessionId, afterSeq];
    } else {
      where = 'session_id = ?';
      whereArgs = [sessionId];
    }

    final rows = await _db.db.query(
      'messages',
      columns: ['data'],
      where: where,
      whereArgs: whereArgs,
      orderBy: afterSeq != null ? 'seq ASC' : 'seq DESC',
      limit: limit,
    );
    final list = rows
        .map((r) =>
            ChatMessage.fromJson(jsonDecode(r['data'] as String)
                as Map<String, dynamic>))
        .toList();
    return list.reversed.toList(); // 转回时间正序
  }

  /// 会话消息总数（来自 messages 表）。
  Future<int> countMessages(String sessionId) async {
    final r = await _db.db.rawQuery(
      'SELECT COUNT(*) AS c FROM messages WHERE session_id = ?',
      [sessionId],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  /// 保存会话：增量 upsert messages 表 + 写入 chat_sessions 元数据。
  Future<void> save(ChatSession session) async {
    await _lock.run(() async {
      await _saveMessages(session.id, session.messages);
      // 总数取表中真实值（内存窗口可能只是子集），保证列表/搜索展示准确
      final total = await countMessages(session.id);
      final meta = ChatSession(
        id: session.id,
        title: session.title,
        type: session.type,
        createdAt: session.createdAt,
        updatedAt: DateTime.now(),
        messages: const [],
        preview: session.messages.isNotEmpty
            ? _previewOf(session.messages.last)
            : null,
        messageCount: total,
      );
      await _db.db.insert(
        'chat_sessions',
        {'id': session.id, 'data': jsonEncode(meta.toJson())},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _sessionCache[session.id] = session;
    });
  }

  /// 增量 upsert：按 (session_id, msg_id) 覆盖，绝不删除其他消息，
  /// 保证窗口之外的历史在表中始终安全。
  Future<void> _saveMessages(
    String sessionId,
    List<ChatMessage> messages,
  ) async {
    await _db.db.transaction((txn) async {
      for (final m in messages) {
        await txn.insert(
          'messages',
          {
            'session_id': sessionId,
            'msg_id': m.id,
            'seq': m.seq,
            'data': jsonEncode(m.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// 删除单条消息（气泡长按「删除」用）：从内存列表移除后调用，删掉表中对应行。
  Future<void> deleteMessage(String sessionId, String msgId) async {
    await _lock.run(() async {
      await _db.db.delete(
        'messages',
        where: 'session_id = ? AND msg_id = ?',
        whereArgs: [sessionId, msgId],
      );
    });
  }

  /// 删除会话。
  Future<void> delete(String id) async {
    await _lock.run(() async {
      await _db.db.delete('chat_sessions', where: 'id = ?', whereArgs: [id]);
      await _db.db
          .delete('messages', where: 'session_id = ?', whereArgs: [id]);
      _sessionCache.remove(id);
    });
  }

  /// 清空内存缓存。
  void clearCache() {
    _sessionCache.clear();
  }

  /// 取最后一条消息的预览文本（最多 40 字，去换行）。
  static String? _previewOf(ChatMessage m) {
    final t = m.text.replaceAll('\n', ' ').trim();
    if (t.isEmpty) return null;
    return t.length > 40 ? '${t.substring(0, 40)}…' : t;
  }
}
