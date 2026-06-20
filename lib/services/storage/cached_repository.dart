import 'dart:async';

import 'package:flutter/foundation.dart';

import '../async_lock.dart';
import 'local_data_source.dart';

/// 带内存缓存的 Repository，把“持久化”与“内存状态”拆成两层。
///
/// - [LocalDataSource] 负责真正的持久化（文件/数据库等）。
/// - 本类负责：缓存、并发控制（[AsyncLock]）、变更通知（[ChangeNotifier]）。
///
/// 所有写操作（[saveAll] / [mutate]）都会序列化执行，避免“读-改-写”竞态。
class CachedRepository<T> extends ChangeNotifier {
  CachedRepository({required LocalDataSource<T> dataSource})
      : _dataSource = dataSource;

  final LocalDataSource<T> _dataSource;
  final AsyncLock _lock = AsyncLock();

  List<T>? _cache;

  /// 返回当前全部数据的可变副本。
  ///
  /// 若缓存尚未加载，直接返回空列表；调用方如需保证最新数据请先调用 [loadAll]。
  List<T> get current => List<T>.from(_cache ?? <T>[]);

  /// 加载全部数据。首次加载会合并并发请求，只读一次文件。
  Future<List<T>> loadAll() async {
    final cached = _cache;
    if (cached != null) return List<T>.from(cached);

    return await _lock.run(() async {
      final cached = _cache;
      if (cached != null) return List<T>.from(cached);

      final loaded = await _dataSource.readAll();
      _cache = List<T>.from(loaded);
      return List<T>.from(_cache!);
    });
  }

  /// 直接用 [items] 覆盖持久化与缓存。
  Future<void> saveAll(List<T> items) async {
    await _lock.run(() async {
      final copy = List<T>.from(items);
      await _dataSource.writeAll(copy);
      _cache = copy;
      notifyListeners();
    });
  }

  /// 在锁保护下“读-改-写”。
  ///
  /// [change] 拿到的是当前数据的可变副本，可直接修改；本方法会自动持久化并刷新缓存。
  Future<void> mutate(FutureOr<void> Function(List<T> items) change) async {
    await _lock.run(() async {
      final current = List<T>.from(_cache ?? await _dataSource.readAll());
      await change(current);
      final copy = List<T>.from(current);
      await _dataSource.writeAll(copy);
      _cache = copy;
      notifyListeners();
    });
  }

  /// 清空内存缓存，下次 [loadAll] 会重新读取持久化。
  void clearCache() => _cache = null;
}
