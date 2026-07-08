import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 应用程序数据库 —— 替代所有 JSON 文件的单一 SQLite 数据库。
///
/// 每张表通用结构：`id TEXT PRIMARY KEY, data TEXT NOT NULL`
/// 其中 `data` 列存储模型的完整 JSON 编码。
/// 这样 `SqliteDataSource<T>` 可以泛型化适配任意模型类型。
///
/// 用法：
/// ```dart
/// final db = AppDatabase.instance;
/// await db.initialize(); // 首次启动自动从 JSON 迁移
/// ```
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  /// 当前数据库版本。
  static const int version = 1;

  /// 所有表的名称清单。
  static const tables = [
    'agents',
    'agent_groups',
    'chat_sessions',
    'notes',
    'reminders',
    'media_items',
  ];

  // ── 初始化 ────────────────────────────────────────────────

  /// 打开或创建数据库。首次创建时执行建表 SQL。
  Future<void> initialize() async {
    if (_db != null) return;
    final dbPath = join(await getDatabasesPath(), 'personal_agent.db');
    _db = await openDatabase(
      dbPath,
      version: version,
      onCreate: (db, ver) => _createTables(db),
    );
  }

  /// 仅用于测试：注入外部 DatabaseFactory（如 sqflite_common_ffi）。
  Future<void> initializeForTest(DatabaseFactory factory) async {
    if (_db != null) return;
    final dbPath = join(await factory.getDatabasesPath(), 'personal_agent_test.db');
    _db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, ver) => _createTables(db),
      ),
    );
  }

  Future<void> _createTables(Database db) async {
    for (final t in tables) {
      await db.execute('''
        CREATE TABLE $t (
          id TEXT PRIMARY KEY,
          data TEXT NOT NULL
        )
      ''');
    }
  }

  // ── 通用查询 ──────────────────────────────────────────────

  Database get db {
    if (_db == null) throw StateError('AppDatabase 未初始化，请先调用 initialize()');
    return _db!;
  }

  /// 读取某张表的全部行，反序列化为 [fromJson]。
  Future<List<T>> readAll<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final rows = await db.query(table, columns: ['data']);
    return rows.map((r) {
      final map = jsonDecode(r['data'] as String) as Map<String, dynamic>;
      return fromJson(map);
    }).toList();
  }

  /// 用 [items] 完全覆盖 [table]。先清空再批量插入。
  Future<void> writeAll<T>({
    required String table,
    required List<T> items,
    required String Function(T) idOf,
    required Map<String, dynamic> Function(T) toJson,
  }) async {
    await db.transaction((txn) async {
      await txn.delete(table);
      for (final item in items) {
        await txn.insert(
          table,
          {
            'id': idOf(item),
            'data': jsonEncode(toJson(item)),
          },
        );
      }
    });
  }

  /// 删除 [table] 中指定 [id] 的行。存在则删除并返回 true，否则 false。
  Future<bool> deleteById({
    required String table,
    required String id,
  }) async {
    final count = await db.delete(table, where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  /// 某张表的行数。
  Future<int> count(String table) async {
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return (result.first['c'] as int?) ?? 0;
  }

  /// 关闭数据库。
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
