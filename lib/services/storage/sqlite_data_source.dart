import 'app_database.dart';
import 'local_data_source.dart';

/// 基于 SQLite 的泛型 [LocalDataSource] 实现。
///
/// 每个实例对应 [AppDatabase] 中的一张表，通过注入的 [toJson]/[fromJson]/[idOf]
/// 函数完成序列化与反序列化，无需为每种模型写单独的数据源。
///
/// **前提**：对应表已由 [AppDatabase.initialize] 创建。
class SqliteDataSource<T> implements LocalDataSource<T> {
  final String table;
  final Map<String, dynamic> Function(T) _toJson;
  final T Function(Map<String, dynamic>) _fromJson;
  final String Function(T) _idOf;
  final AppDatabase _db;

  SqliteDataSource({
    required this.table,
    required AppDatabase db,
    required Map<String, dynamic> Function(T) toJson,
    required T Function(Map<String, dynamic>) fromJson,
    required String Function(T) idOf,
  }) : _toJson = toJson,
       _fromJson = fromJson,
       _idOf = idOf,
       _db = db;

  @override
  Future<List<T>> readAll() =>
      _db.readAll(table: table, fromJson: _fromJson);

  @override
  Future<void> writeAll(List<T> items) =>
      _db.writeAll(table: table, items: items, idOf: _idOf, toJson: _toJson);
}
