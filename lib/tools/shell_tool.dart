import '../services/sandbox_service.dart';
import '../services/log_service.dart';
import 'base_tool.dart';

/// Linux 沙箱 Shell 工具
class ShellTool extends AgentTool {
  final SandboxService _sandbox = SandboxService();

  @override
  String get name => 'shell';

  @override
  String get description => '在 Linux 沙箱中执行命令。支持 bash/sh 脚本、文件操作、包管理（apk add）等。';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'command': {
        'type': 'string',
        'description': '要执行的 shell 命令',
      },
      'working_dir': {
        'type': 'string',
        'description': '工作目录（可选，默认 /root）',
      },
    },
    'required': ['command'],
  };

  @override
  bool get readOnly => false;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final command = args['command'] as String?;
    if (command == null || command.isEmpty) {
      return '错误: 请提供要执行的命令';
    }

    final workingDir = args['working_dir'] as String?;

    if (_sandbox.state != SandboxState.ready) {
      final initialized = await _sandbox.init();
      if (!initialized) {
        return '错误: Linux 沙箱初始化失败。请确保 proot 和 Alpine rootfs 已就绪。';
      }
    }

    log.i('ShellTool', '执行: $command');
    final result = await _sandbox.execute(command, workingDir: workingDir);

    final buf = StringBuffer();
    if (result.stdout.isNotEmpty) buf.write(result.stdout);
    if (result.stderr.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.write('STDERR: ${result.stderr}');
    }
    if (!result.isSuccess) {
      buf.writeln();
      buf.write('退出码: ${result.exitCode}');
    }

    return buf.toString().isEmpty ? '命令执行成功（无输出）' : buf.toString();
  }
}

/// 沙箱状态查看工具
class SandboxStatusTool extends AgentTool {
  final SandboxService _sandbox = SandboxService();

  @override
  String get name => 'sandbox_status';

  @override
  String get description => '查看 Linux 沙箱状态（是否就绪、根目录等）。';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {},
    'required': [],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    return '沙箱状态: ${_sandbox.state.name}\n'
        '根目录: ${_sandbox.rootDir ?? '未初始化'}';
  }
}
