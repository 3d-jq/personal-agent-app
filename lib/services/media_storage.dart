import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/media_item.dart';

class MediaStorage {
  MediaStorage();

  List<MediaItem>? _cache;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/media.json');
  }

  Future<List<MediaItem>> loadAll() async {
    if (_cache != null) return _cache!;
    try {
      final file = await _file();
      if (!await file.exists()) {
        _cache = [];
        return [];
      }
      final list = jsonDecode(await file.readAsString()) as List;
      _cache =
          list
              .map((j) => MediaItem.fromJson(j as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _cache!;
    } catch (_) {
      _cache = [];
      return [];
    }
  }

  Future<void> add(MediaItem item) async {
    final all = await loadAll();
    all.insert(0, item);
    await _save(all);
  }

  Future<void> remove(String id) async {
    final all = await loadAll();
    final item = all.firstWhere(
      (m) => m.id == id,
      orElse: () =>
          MediaItem(id: '', type: MediaType.image, filePath: '', prompt: ''),
    );
    if (item.filePath.isNotEmpty) {
      final file = File(item.filePath);
      if (await file.exists()) await file.delete();
    }
    all.removeWhere((m) => m.id == id);
    await _save(all);
  }

  Future<void> _save(List<MediaItem> all) async {
    _cache = all;
    final file = await _file();
    await file.writeAsString(jsonEncode(all.map((e) => e.toJson()).toList()));
  }
}
