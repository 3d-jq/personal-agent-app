import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 虚拟文件系统节点类型
enum FSNodeType { file, directory }

/// 虚拟文件系统节点
class FSNode {
  final String name;
  final FSNodeType type;
  final String? content; // 仅 file 类型有内容
  final List<FSNode> children; // 仅 directory 类型有子节点

  FSNode.file(this.name, {this.content}) : type = FSNodeType.file, children = [];
  FSNode.directory(this.name, {List<FSNode>? children}) : type = FSNodeType.directory, content = null, children = children ?? [];

  /// 获取文件大小（字节）
  int get size => content?.length ?? 0;

  /// 格式化显示
  String toDisplayString() {
    if (type == FSNodeType.directory) return '$name/';
    final kb = (size / 1024).toStringAsFixed(1);
    return '$name ($kb KB)';
  }
}

/// 虚拟文件系统服务
///
/// 管理 Agent 的虚拟文件树，支持 ls/read/write/mkdir/rm 操作。
/// 文件存储在应用文档目录的 `virtual_fs/` 子目录下。
class VirtualFileSystem {
  static final VirtualFileSystem _instance = VirtualFileSystem._();
  factory VirtualFileSystem() => _instance;
  VirtualFileSystem._();

  Directory? _rootDir;

  /// 获取虚拟文件系统根目录
  Future<Directory> getRoot() async {
    if (_rootDir != null) return _rootDir!;
    final base = await getApplicationDocumentsDirectory();
    _rootDir = Directory('${base.path}/virtual_fs');
    if (!await _rootDir!.exists()) {
      await _rootDir!.create(recursive: true);
    }
    return _rootDir!;
  }

  /// 将虚拟路径转换为实际文件系统路径
  Future<String> _resolvePath(String virtualPath) async {
    final root = await getRoot();
    // 移除开头的 / 并规范化
    final cleanPath = virtualPath.startsWith('/') ? virtualPath.substring(1) : virtualPath;
    if (cleanPath.isEmpty) return root.path;
    return '${root.path}/$cleanPath';
  }

  /// 列出目录内容
  Future<List<FSNode>> ls(String path) async {
    final realPath = await _resolvePath(path);
    final dir = Directory(realPath);

    if (!await dir.exists()) {
      throw FileSystemException('目录不存在', path);
    }

    final nodes = <FSNode>[];
    await for (final entity in dir.list()) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (entity is Directory) {
        nodes.add(FSNode.directory(name));
      } else if (entity is File) {
        final content = await entity.readAsString();
        nodes.add(FSNode.file(name, content: content));
      }
    }

    // 目录在前，文件在后，按名称排序
    nodes.sort((a, b) {
      if (a.type != b.type) {
        return a.type == FSNodeType.directory ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });

    return nodes;
  }

  /// 读取文件内容
  Future<String> read(String path) async {
    final realPath = await _resolvePath(path);
    final file = File(realPath);

    if (!await file.exists()) {
      throw FileSystemException('文件不存在', path);
    }

    return await file.readAsString();
  }

  /// 写入文件内容（自动创建中间目录）
  Future<void> write(String path, String content) async {
    final realPath = await _resolvePath(path);
    final file = File(realPath);

    // 确保父目录存在
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    await file.writeAsString(content);
  }

  /// 创建目录
  Future<void> mkdir(String path) async {
    final realPath = await _resolvePath(path);
    final dir = Directory(realPath);

    if (await dir.exists()) {
      return; // 目录已存在
    }

    await dir.create(recursive: true);
  }

  /// 删除文件或空目录
  Future<void> rm(String path) async {
    final realPath = await _resolvePath(path);
    final entity = FileSystemEntity.typeSync(realPath);

    if (entity == FileSystemEntityType.notFound) {
      throw FileSystemException('路径不存在', path);
    }

    if (entity == FileSystemEntityType.directory) {
      final dir = Directory(realPath);
      // 只允许删除空目录
      if (await dir.list().isEmpty) {
        await dir.delete();
      } else {
        throw FileSystemException('目录不为空，请先删除内部文件', path);
      }
    } else {
      final file = File(realPath);
      await file.delete();
    }
  }

  /// 检查路径是否存在
  Future<bool> exists(String path) async {
    final realPath = await _resolvePath(path);
    final entity = FileSystemEntity.typeSync(realPath);
    return entity != FileSystemEntityType.notFound;
  }

  /// 递归列出所有文件（用于搜索）
  Future<List<String>> walk(String path) async {
    final realPath = await _resolvePath(path);
    final dir = Directory(realPath);

    if (!await dir.exists()) {
      return [];
    }

    final files = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        // 返回相对于根目录的路径
        final root = await getRoot();
        final relative = entity.path.substring(root.path.length + 1);
        files.add(relative);
      }
    }

    return files;
  }
}
