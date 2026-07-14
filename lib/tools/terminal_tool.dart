import '../platform/terminal_channel.dart';
import '../services/log_service.dart';
import 'base_tool.dart';
import 'plugin_registry.dart';
import 'tool_registry.dart';

/// 终端工具基础类：统一持有 [TerminalChannel]，execute 委托给原生宿主。
abstract class TerminalBaseTool extends AgentTool {
  final TerminalChannel channel;

  TerminalBaseTool(this.channel);

  @override
  bool get readOnly => false;
}

/// 在终端沙箱执行一条 shell 命令并返回输出（AI 自动化用，无头执行）。
class TerminalRunTool extends TerminalBaseTool {
  TerminalRunTool(super.channel);
  @override
  String get name => 'terminal_run';
  @override
  String get description =>
      '在终端沙箱（Android 用户态 PRoot + 内置 Ubuntu）中执行一条 shell 命令，'
      '返回标准输出、退出码与状态（state 为 OK/TIMEOUT/EXECUTION_ERROR 等）。'
      '适用于在隔离环境跑脚本、调用 linux 命令、编译/运行程序、读写沙箱内文件等。'
      '命令为一次性无头执行，不保留上一条命令的 cd 目录或环境变量。';
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'command': {
            'type': 'string',
            'description': '要执行的 shell 命令，例如 "ls -la /workspace" 或 "python3 --version"',
          },
          'timeoutMs': {
            'type': 'integer',
            'description': '超时毫秒数，默认 30000（30 秒），长任务可调大',
          },
        },
        'required': ['command'],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final command = (args['command'] as String?)?.trim() ?? '';
    if (command.isEmpty) return '错误：command 为空';
    final timeoutMs = (args['timeoutMs'] as int?) ?? 30000;
    try {
      final r = await channel.exec(command, timeoutMs: timeoutMs);
      final buf = StringBuffer();
      buf.writeln('状态: ${r.state}  退出码: ${r.exitCode}');
      if (r.error.isNotEmpty) buf.writeln('错误: ${r.error}');
      buf.writeln('---- 输出 ----');
      final out = r.output.trim();
      buf.write(out.isEmpty ? '(无输出)' : out);
      return buf.toString();
    } on TerminalException catch (e) {
      log.e('Terminal', e.message, e.cause);
      return '终端执行失败：${e.message}';
    }
  }
}

/// 检查终端沙箱是否就绪（PRoot + Ubuntu 环境已初始化）。
class TerminalStatusTool extends TerminalBaseTool {
  TerminalStatusTool(super.channel);
  @override
  String get name => 'terminal_status';
  @override
  bool get readOnly => true;
  @override
  String get description => '检查终端沙箱环境是否已就绪（PRoot + Ubuntu 初始化是否完成）。只读，可随时调用。';
  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      };
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final res = await channel.ensureReady();
      if (res.ready) return '终端沙箱已就绪';
      final diag = res.diag.isNotEmpty ? '\n诊断: ${res.diag}' : '';
      return '终端沙箱未就绪$diag';
    } on TerminalException catch (e) {
      log.e('Terminal', e.message, e.cause);
      return '终端沙箱不可用：${e.message}';
    }
  }
}

/// 终端能力插件：把终端工具注入会话 ToolRegistry。
class TerminalToolsPlugin extends AppPlugin {
  final TerminalChannel channel;

  TerminalToolsPlugin([TerminalChannel? channel])
      : channel = channel ?? TerminalChannel();

  @override
  String get id => 'terminal';

  @override
  Future<void> init() async {}

  @override
  void provideTools(ToolRegistry registry) {
    if (!registry.has('terminal_status')) {
      registry.register(TerminalStatusTool(channel));
    }
    if (!registry.has('terminal_run')) {
      registry.register(TerminalRunTool(channel));
    }
  }
}
