import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../tools/base_tool.dart';
import 'file_tool.g.dart';

class FileTool extends AgentTool {
  @override
  String get name => 'file_manager';
  @override
  bool get readOnly => false;

  @override
  String get description => fileToolDescription;

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['list', 'read', 'write', 'append', 'mkdir', 'delete'],
        'description':
            '操作类型：list(列目录), read(读文件), write(写文件), append(追加文件), mkdir(创建目录), delete(删除)',
      },
      'path': {'type': 'string', 'description': '文件/文件夹路径（相对于应用文档目录）'},
      'content': {
        'type': 'string',
        'description': '写入/追加时的内容（write/append操作需要）',
      },
    },
    'required': ['action', 'path'],
  };

  Future<Directory> _getBaseDir() async {
    return await getApplicationDocumentsDirectory();
  }

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String?;
    final path = args['path'] as String?;

    if (action == null || path == null) {
      return '错误: 请提供操作类型(action)和路径(path)';
    }

    try {
      final baseDir = await _getBaseDir();
      final fullPath =
          '${baseDir.path}/${path.replaceAll(RegExp(r'^[/\\]'), '')}';
      final file = File(fullPath);
      final dir = Directory(fullPath);

      switch (action) {
        case 'list':
          return await _list(dir, path);
        case 'read':
          return await _read(file, path);
        case 'write':
          return await _write(file, path, args['content'] as String?);
        case 'append':
          return await _append(file, path, args['content'] as String?);
        case 'mkdir':
          return await _mkdir(dir, path);
        case 'delete':
          return await _delete(fullPath, path);
        default:
          return '错误: 不支持的操作 "$action"';
      }
    } catch (e) {
      return '文件操作错误: $e';
    }
  }

  Future<String> _list(Directory dir, String path) async {
    if (!await dir.exists()) {
      return '目录不存在: $path';
    }
    final entries = await dir.list().toList();
    if (entries.isEmpty) {
      return '目录为空: $path';
    }

    final buf = StringBuffer('目录内容: $path\n');
    for (final entry in entries) {
      final isDir = entry is Directory;
      final name = entry.path.split(Platform.pathSeparator).last;
      buf.writeln('${isDir ? "[DIR]" : "[FILE]"} $name');
    }
    return buf.toString().trim();
  }

  Future<String> _read(File file, String path) async {
    if (!await file.exists()) {
      return '文件不存在: $path';
    }
    final content = await file.readAsString();
    if (content.isEmpty) {
      return '文件为空: $path';
    }
    return '文件内容 ($path):\n$content';
  }

  Future<String> _write(File file, String path, String? content) async {
    if (content == null) {
      return '错误: write 操作需要提供 content 参数';
    }
    final parentDir = file.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }
    await file.writeAsString(content);
    return '已写入文件: $path (${content.length} 字符)';
  }

  Future<String> _append(File file, String path, String? content) async {
    if (content == null) {
      return '错误: append 操作需要提供 content 参数';
    }
    if (!await file.exists()) {
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
    }
    await file.writeAsString(content, mode: FileMode.append);
    return '已追加到文件: $path (${content.length} 字符)';
  }

  Future<String> _mkdir(Directory dir, String path) async {
    await dir.create(recursive: true);
    return '已创建目录: $path';
  }

  Future<String> _delete(String fullPath, String path) async {
    final file = File(fullPath);
    if (await file.exists()) {
      await file.delete();
      return '已删除文件: $path';
    }
    final dir = Directory(fullPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      return '已删除目录: $path';
    }
    return '文件/目录不存在: $path';
  }
}
