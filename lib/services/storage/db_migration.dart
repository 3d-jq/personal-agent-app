import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/chat_message.dart';
import 'app_database.dart';

/// 将现有的 JSON 文件数据一次性迁移到 SQLite。
///
/// 迁移规则：
/// - 仅当对应 SQLite 表为空时才执行（幂等，不会重复迁移）
/// - 旧 JSON 文件**不删除**（作为备份保留）
/// - 若某 JSON 文件不存在或损坏，跳过该表，不阻塞整体迁移
class DbMigration {
  /// 执行迁移。返回迁移的表数。
  static Future<int> run() async {
    final db = AppDatabase.instance;
    final dir = await getApplicationDocumentsDirectory();
    var migrated = 0;

    // agents.json → agents
    if (await _shouldMigrate(db, 'agents')) {
      final items = await _readJsonFile(dir, 'agents.json');
      if (items != null) {
        await db.writeAll(
          table: 'agents',
          items: items,
          idOf: (dynamic m) => m['id'] as String,
          toJson: (m) => m,
        );
        migrated++;
      }
    }

    // agent_groups.json → agent_groups
    if (await _shouldMigrate(db, 'agent_groups')) {
      final items = await _readJsonFile(dir, 'agent_groups.json');
      if (items != null) {
        await db.writeAll(
          table: 'agent_groups',
          items: items,
          idOf: (dynamic m) => m['id'] as String,
          toJson: (m) => m,
        );
        migrated++;
      }
    }

    // notes.json → notes
    if (await _shouldMigrate(db, 'notes')) {
      final items = await _readJsonFile(dir, 'notes.json');
      if (items != null) {
        await db.writeAll(
          table: 'notes',
          items: items,
          idOf: (dynamic m) => m['id'].toString(),
          toJson: (m) => m,
        );
        migrated++;
      }
    }

    // reminders.json → reminders
    if (await _shouldMigrate(db, 'reminders')) {
      final items = await _readJsonFile(dir, 'reminders.json');
      if (items != null) {
        await db.writeAll(
          table: 'reminders',
          items: items,
          idOf: (dynamic m) => m['id'].toString(),
          toJson: (m) => m,
        );
        migrated++;
      }
    }

    // media.json → media_items
    if (await _shouldMigrate(db, 'media_items')) {
      final items = await _readJsonFile(dir, 'media.json');
      if (items != null) {
        await db.writeAll(
          table: 'media_items',
          items: items,
          idOf: (dynamic m) => m['id'].toString(),
          toJson: (m) => m,
        );
        migrated++;
      }
    }

    // sessions/index.json → chat_sessions
    if (await _shouldMigrate(db, 'chat_sessions')) {
      final sessions = await _readJsonFile(dir, 'sessions/index.json');
      if (sessions != null) {
        // 对每个 session，读取其完整 {id}.json 文件
        final fullSessions = <Map<String, dynamic>>[];
        for (final meta in sessions) {
          final id = meta['id'] as String?;
          if (id == null) continue;
          final fullList = await _readJsonFile(dir, 'sessions/$id.json');
          if (fullList != null && fullList.isNotEmpty) {
            fullSessions.add(fullList.first);
          }
        }
        await db.writeAll(
          table: 'chat_sessions',
          items: fullSessions,
          idOf: (dynamic m) => m['id'] as String,
          toJson: (m) => m,
        );
        migrated++;
      }
    }

    // chat_sessions 消息体拆分到 messages 表（仅当 messages 表为空且 chat_sessions 有数据）
    // 拆分后 chat_sessions 仅保留元数据（preview/messageCount），消除「打开会话加载全量」。
    if (await db.count('messages') == 0 && await db.count('chat_sessions') > 0) {
      final rows = await db.db.query('chat_sessions', columns: ['id', 'data']);
      for (final row in rows) {
        final id = row['id'] as String;
        final map =
            jsonDecode(row['data'] as String) as Map<String, dynamic>;
        final msgs = (map['messages'] as List?)
                ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
                .toList() ??
            <ChatMessage>[];
        // 写入 messages 表（seq = 下标，保证全局顺序稳定）
        await db.db.transaction((txn) async {
          for (var i = 0; i < msgs.length; i++) {
            final m = msgs[i];
            m.seq = i;
            await txn.insert(
              'messages',
              {
                'session_id': id,
                'msg_id': m.id,
                'seq': m.seq,
                'data': jsonEncode(m.toJson()),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });
        // 重写 chat_sessions 为元数据（去掉 messages 数组，加 preview/count）
        final preview = msgs.isNotEmpty ? _previewOf(msgs.last) : null;
        final newMap = {
          'id': id,
          'title': map['title'] ?? '新对话',
          'createdAt': map['createdAt'] ?? 0,
          'updatedAt': map['updatedAt'] ?? 0,
          'type': map['type'] ?? 'chat',
          if (preview != null) 'preview': preview,
          'messageCount': msgs.length,
        };
        await db.db.update(
          'chat_sessions',
          {'data': jsonEncode(newMap)},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      migrated++;
    }

    return migrated;
  }

  /// 检查是否应执行迁移：表存在且为空。
  static Future<bool> _shouldMigrate(AppDatabase db, String table) async {
    final c = await db.count(table);
    return c == 0;
  }

  /// 读取 JSON 文件并返回 List<Map>，不存在或损坏则返回 null。
  static Future<List<Map<String, dynamic>>?> _readJsonFile(
    Directory dir,
    String relativePath,
  ) async {
    try {
      final file = File('${dir.path}/$relativePath');
      if (!file.existsSync()) return null;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 取最后一条消息的预览文本（最多 40 字，去换行）。
  static String? _previewOf(ChatMessage m) {
    final t = m.text.replaceAll('\n', ' ').trim();
    if (t.isEmpty) return null;
    return t.length > 40 ? '${t.substring(0, 40)}…' : t;
  }
}
