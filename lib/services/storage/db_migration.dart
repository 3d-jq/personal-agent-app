import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

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
}
