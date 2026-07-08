import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/media_item.dart';
import 'async_lock.dart';

/// 媒体库存储。
///
/// 所有媒体元数据保存在 `media.json` 中，文件操作带锁保护，
/// 并通过内存缓存避免频繁反序列化。
class MediaStorage {
  MediaStorage() : _lock = AsyncLock();

  final AsyncLock _lock;
  List<MediaItem>? _cache;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/media.json');
  }

  Future<List<MediaItem>> loadAll() async {
    final cached = _cache;
    if (cached != null) return List.unmodifiable(cached);

    return _lock.run(() async {
      final cached = _cache;
      if (cached != null) return List.unmodifiable(cached);

      final file = await _file();
      if (!await file.exists()) {
        _cache = [];
        return [];
      }

      try {
        final list = jsonDecode(await file.readAsString()) as List;
        final items = list
            .map((j) => MediaItem.fromJson(j as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _cache = items;
        return List.unmodifiable(items);
      } catch (_) {
        _cache = [];
        return [];
      }
    });
  }

  Future<void> add(MediaItem item) async {
    await _lock.run(() async {
      final all = List<MediaItem>.from(_cache ?? await _loadUnsafe());
      all.insert(0, item);
      await _saveUnsafe(all);
    });
  }

  Future<void> remove(String id) async {
    await _lock.run(() async {
      final all = List<MediaItem>.from(_cache ?? await _loadUnsafe());
      final idx = all.indexWhere((m) => m.id == id);
      if (idx < 0) return;

      final item = all[idx];
      if (item.filePath.isNotEmpty) {
        final file = File(item.filePath);
        if (await file.exists()) await file.delete();
      }
      all.removeAt(idx);
      await _saveUnsafe(all);
    });
  }

  Future<List<MediaItem>> _loadUnsafe() async {
    final file = await _file();
    if (!await file.exists()) {
      _cache = [];
      return [];
    }
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      final items = list
          .map((j) => MediaItem.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cache = items;
      return items;
    } catch (_) {
      _cache = [];
      return [];
    }
  }

  Future<void> _saveUnsafe(List<MediaItem> all) async {
    _cache = List.unmodifiable(all);
    final file = await _file();
    await file.writeAsString(jsonEncode(all.map((e) => e.toJson()).toList()));
  }
}
