import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'local_data_source.dart';

/// 基于 JSON 文件的本地数据源实现。
///
/// [relativePath] 相对于应用文档目录的路径，可包含子目录（如 `sessions/index.json`）。
/// 读写失败时可选地备份损坏文件并返回空列表，避免整个应用崩溃。
class JsonFileDataSource<T> implements LocalDataSource<T> {
  JsonFileDataSource({
    required this.relativePath,
    required this.fromJson,
    required this.toJson,
    this.backupOnCorruption = true,
  });

  final String relativePath;
  final List<T> Function(List<dynamic> json) fromJson;
  final List<dynamic> Function(List<T> items) toJson;
  final bool backupOnCorruption;

  Future<File> _file() async {
    final base = await getApplicationDocumentsDirectory();
    final file = File('${base.path}/$relativePath');
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return file;
  }

  @override
  Future<List<T>> readAll() async {
    final file = await _file();
    if (!await file.exists()) return <T>[];

    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as List<dynamic>;
      return fromJson(json);
    } catch (e, stackTrace) {
      if (backupOnCorruption) {
        await _backupCorruptedFile(file);
      }
      assert(() {
        // ignore: avoid_print
        print('JsonFileDataSource read error: $e\n$stackTrace');
        return true;
      }());
      return <T>[];
    }
  }

  @override
  Future<void> writeAll(List<T> items) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(toJson(items)));
  }

  Future<void> _backupCorruptedFile(File file) async {
    try {
      final backup = File('${file.path}.bak.${DateTime.now().millisecondsSinceEpoch}');
      await file.rename(backup.path);
    } catch (_) {
      // 备份也失败时静默忽略，至少不阻塞后续写入。
    }
  }
}
