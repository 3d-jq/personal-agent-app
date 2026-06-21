import 'dart:io';
import 'base_tool.dart';
import '../services/virtual_fs.dart';

/// 虚拟文件系统工具
///
/// Agent 可通过此工具管理虚拟文件系统：
/// - ls: 列出目录内容
/// - read: 读取文件
/// - write: 写入文件
/// - mkdir: 创建目录
/// - rm: 删除文件
/// - walk: 递归列出所有文件
class VirtualFSTool extends AgentTool {
  @override
  String get name => 'virtual_fs';

  @override
  bool get readOnly => false;

  @override
  String get description => '''
管理虚拟文件系统，用于组织和管理上下文信息。
路径以 / 开头表示从根目录开始，如 /memory/notes.md、/scratch/idea.md
目录结构：
- /soul/     人格设定（只读，由用户配置）
- /user/     用户信息
- /agent/    Agent 经验积累
- /memory/   长期记忆
- /scratch/  临时草稿
- /notes/    用户笔记
- /knowledge/ 知识库（只读）

操作：
- ls: 列出目录内容
- read: 读取文件内容
- write: 写入或创建文件
- mkdir: 创建目录
- rm: 删除文件（仅空目录可删）
- walk: 递归列出所有文件路径'''.trim();

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['ls', 'read', 'write', 'mkdir', 'rm', 'walk'],
            'description': '操作类型',
          },
          'path': {
            'type': 'string',
            'description': '文件或目录路径，如 /memory/notes.md',
          },
          'content': {
            'type': 'string',
            'description': 'write 操作时的文件内容',
          },
        },
        'required': ['action', 'path'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String?;
    final path = args['path'] as String?;

    if (action == null || path == null) {
      return '错误：必须提供 action 和 path 参数。';
    }

    final fs = VirtualFileSystem();

    try {
      switch (action) {
        case 'ls':
          final nodes = await fs.ls(path);
          if (nodes.isEmpty) return '目录为空。';
          final buffer = StringBuffer('【$path】\n');
          for (final node in nodes) {
            buffer.writeln('  ${node.type == FSNodeType.directory ? '📁 ' : '📄 '}${node.toDisplayString()}');
          }
          return buffer.toString();

        case 'read':
          final content = await fs.read(path);
          if (content.trim().isEmpty) return '【$path】文件为空。';
          return '【$path】\n$content';

        case 'write':
          final content = args['content'] as String?;
          if (content == null) {
            return '错误：write 操作需要提供 content 参数。';
          }
          await fs.write(path, content);
          return '已写入 $path（${content.length} 字符）';

        case 'mkdir':
          await fs.mkdir(path);
          return '已创建目录 $path';

        case 'rm':
          await fs.rm(path);
          return '已删除 $path';

        case 'walk':
          final files = await fs.walk(path);
          if (files.isEmpty) return '没有找到文件。';
          final buffer = StringBuffer('【$path 下所有文件】\n');
          for (final file in files) {
            buffer.writeln('  📄 $file');
          }
          return buffer.toString();

        default:
          return '错误：不支持的操作 "$action"';
      }
    } on FileSystemException catch (e) {
      return '文件系统错误：${e.message}';
    } catch (e) {
      return '错误：$e';
    }
  }
}
