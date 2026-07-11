import 'dart:io';
import 'base_tool.dart';
import '../core/service_locator.dart';
import '../services/virtual_fs.dart';
import 'fs_ls_tool.g.dart';
import 'fs_read_tool.g.dart';
import 'fs_write_tool.g.dart';
import 'fs_mkdir_tool.g.dart';
import 'fs_rm_tool.g.dart';
import 'fs_walk_tool.g.dart';

/// 虚拟文件系统工具。
///
/// 原 `virtual_fs`（带 action 参数）已拆分为 6 个独立工具，各自独占调用配额：
/// - [FsLsTool]    列出目录内容
/// - [FsReadTool]  读取文件
/// - [FsWriteTool] 写入文件
/// - [FsMkdirTool] 创建目录
/// - [FsRmTool]    删除文件
/// - [FsWalkTool]  递归列出所有文件
abstract class _VirtualFSBase extends AgentTool {
  @override
  bool get readOnly => false;

  VirtualFileSystem get _fs => getIt<VirtualFileSystem>();

  Future<String> ls(String path) async {
    final nodes = await _fs.ls(path);
    if (nodes.isEmpty) return '目录为空。';
    final buffer = StringBuffer('【$path】\n');
    for (final node in nodes) {
      buffer.writeln(
        '  ${node.type == FSNodeType.directory ? '📁 ' : '📄 '}${node.toDisplayString()}',
      );
    }
    return buffer.toString();
  }

  Future<String> read(String path) async {
    final content = await _fs.read(path);
    if (content.trim().isEmpty) return '【$path】文件为空。';
    return '【$path】\n$content';
  }

  Future<String> write(String path, String content) async {
    await _fs.write(path, content);
    return '已写入 $path（${content.length} 字符）';
  }

  Future<String> mkdir(String path) async {
    await _fs.mkdir(path);
    return '已创建目录 $path';
  }

  Future<String> rm(String path) async {
    await _fs.rm(path);
    return '已删除 $path';
  }

  Future<String> walk(String path) async {
    final files = await _fs.walk(path);
    if (files.isEmpty) return '没有找到文件。';
    final buffer = StringBuffer('【$path 下所有文件】\n');
    for (final file in files) {
      buffer.writeln('  📄 $file');
    }
    return buffer.toString();
  }
}

/// 列出目录内容。
class FsLsTool extends _VirtualFSBase {
  @override
  String get name => 'fs_ls';
  @override
  String get description => fsLsToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'path': {'type': 'string', 'description': '目录路径，如 /memory'},
    },
    'required': ['path'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    if (path == null) return '错误：必须提供 path 参数。';
    try {
      return await ls(path);
    } on FileSystemException catch (e) {
      return '文件系统错误：${e.message}';
    } catch (e) {
      return '错误：$e';
    }
  }
}

/// 读取文件内容。
class FsReadTool extends _VirtualFSBase {
  @override
  String get name => 'fs_read';
  @override
  String get description => fsReadToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'path': {'type': 'string', 'description': '文件路径，如 /memory/notes.md'},
    },
    'required': ['path'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    if (path == null) return '错误：必须提供 path 参数。';
    try {
      return await read(path);
    } on FileSystemException catch (e) {
      return '文件系统错误：${e.message}';
    } catch (e) {
      return '错误：$e';
    }
  }
}

/// 写入文件内容。
class FsWriteTool extends _VirtualFSBase {
  @override
  String get name => 'fs_write';
  @override
  String get description => fsWriteToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'path': {'type': 'string', 'description': '文件路径，如 /memory/notes.md'},
      'content': {'type': 'string', 'description': '文件内容'},
    },
    'required': ['path', 'content'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    final content = args['content'] as String?;
    if (path == null) return '错误：必须提供 path 参数。';
    if (content == null) return '错误：write 操作需要提供 content 参数。';
    try {
      return await write(path, content);
    } on FileSystemException catch (e) {
      return '文件系统错误：${e.message}';
    } catch (e) {
      return '错误：$e';
    }
  }
}

/// 创建目录。
class FsMkdirTool extends _VirtualFSBase {
  @override
  String get name => 'fs_mkdir';
  @override
  String get description => fsMkdirToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'path': {'type': 'string', 'description': '目录路径，如 /memory/project'},
    },
    'required': ['path'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    if (path == null) return '错误：必须提供 path 参数。';
    try {
      return await mkdir(path);
    } on FileSystemException catch (e) {
      return '文件系统错误：${e.message}';
    } catch (e) {
      return '错误：$e';
    }
  }
}

/// 删除文件。
class FsRmTool extends _VirtualFSBase {
  @override
  String get name => 'fs_rm';
  @override
  String get description => fsRmToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'path': {'type': 'string', 'description': '文件路径，如 /memory/notes.md'},
    },
    'required': ['path'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    if (path == null) return '错误：必须提供 path 参数。';
    try {
      return await rm(path);
    } on FileSystemException catch (e) {
      return '文件系统错误：${e.message}';
    } catch (e) {
      return '错误：$e';
    }
  }
}

/// 递归列出目录下所有文件。
class FsWalkTool extends _VirtualFSBase {
  @override
  String get name => 'fs_walk';
  @override
  String get description => fsWalkToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'path': {'type': 'string', 'description': '目录路径，如 /memory'},
    },
    'required': ['path'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    if (path == null) return '错误：必须提供 path 参数。';
    try {
      return await walk(path);
    } on FileSystemException catch (e) {
      return '文件系统错误：${e.message}';
    } catch (e) {
      return '错误：$e';
    }
  }
}
