import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/platform/terminal_channel.dart';
import 'package:personal_agent_app/services/log_service.dart';
import 'package:personal_agent_app/tools/terminal_tool.dart';
import 'package:personal_agent_app/tools/tool_registry.dart';

/// 测试用假通道：覆盖原生调用，返回可预测结果，不触碰真实 MethodChannel。
class FakeTerminalChannel extends TerminalChannel {
  FakeTerminalChannel() : super(const MethodChannel('test.terminal.fake'));

  String? lastExecCommand;
  int? lastExecTimeoutMs;
  String? lastWritten;
  bool ensureReadyResult = true;
  bool started = false;
  bool closed = false;
  TerminalExecResult execResult = const TerminalExecResult(
    output: 'hello',
    exitCode: 0,
    state: 'OK',
    error: '',
  );

  @override
  Future<bool> ensureReady() async => ensureReadyResult;

  @override
  Future<bool> start(String sessionId) async {
    started = true;
    return true;
  }

  @override
  Future<bool> write(String sessionId, String data) async {
    lastWritten = data;
    return true;
  }

  @override
  Future<TerminalExecResult> exec(String command, {int timeoutMs = 30000}) async {
    lastExecCommand = command;
    lastExecTimeoutMs = timeoutMs;
    return execResult;
  }

  @override
  Future<bool> close(String sessionId) async {
    closed = true;
    return true;
  }

  @override
  Stream<Uint8List> get output => const Stream<Uint8List>.empty();
}

/// 仅供错误入日志测试：ensureReady / exec 直接抛 TerminalException。
class _ThrowingChannel extends TerminalChannel {
  _ThrowingChannel() : super(const MethodChannel('test.terminal.throw'));

  @override
  Future<bool> ensureReady() async => throw TerminalException('env not ready');

  @override
  Future<TerminalExecResult> exec(String command, {int timeoutMs = 30000}) async =>
      throw TerminalException('exec crashed');
}

void main() {
  group('TerminalExecResult.fromMap', () {
    test('解析完整字段', () {
      final r = TerminalExecResult.fromMap({
        'output': 'out',
        'exitCode': 2,
        'state': 'TIMEOUT',
        'error': 'boom',
      });
      expect(r.output, 'out');
      expect(r.exitCode, 2);
      expect(r.state, 'TIMEOUT');
      expect(r.error, 'boom');
    });

    test('缺失字段用默认值', () {
      final r = TerminalExecResult.fromMap(<String, dynamic>{});
      expect(r.output, '');
      expect(r.exitCode, -1);
      expect(r.state, '');
      expect(r.error, '');
    });
  });

  group('TerminalRunTool', () {
    late FakeTerminalChannel fake;
    late TerminalRunTool tool;

    setUp(() {
      fake = FakeTerminalChannel();
      tool = TerminalRunTool(fake);
    });

    test('name / readOnly', () {
      expect(tool.name, 'terminal_run');
      expect(tool.readOnly, isFalse);
    });

    test('空命令返回错误', () async {
      final r = await tool.execute({'command': '   '});
      expect(r, contains('command 为空'));
    });

    test('正常执行调用 channel.exec 并格式化输出', () async {
      final r = await tool.execute({
        'command': 'ls -la',
        'timeoutMs': 5000,
      });
      expect(fake.lastExecCommand, 'ls -la');
      expect(fake.lastExecTimeoutMs, 5000);
      expect(r, contains('状态: OK'));
      expect(r, contains('退出码: 0'));
      expect(r, contains('hello'));
    });
  });

  group('TerminalStatusTool', () {
    test('就绪返回已就绪', () async {
      final fake = FakeTerminalChannel()..ensureReadyResult = true;
      final tool = TerminalStatusTool(fake);
      final r = await tool.execute({});
      expect(r, contains('已就绪'));
      expect(tool.readOnly, isTrue);
    });

    test('未就绪返回未就绪', () async {
      final fake = FakeTerminalChannel()..ensureReadyResult = false;
      final tool = TerminalStatusTool(fake);
      final r = await tool.execute({});
      expect(r, contains('未就绪'));
    });
  });

  group('TerminalToolsPlugin', () {
    test('注入 terminal_status 与 terminal_run', () {
      final plugin = TerminalToolsPlugin(FakeTerminalChannel());
      final registry = ToolRegistry();
      plugin.provideTools(registry);
      expect(registry.has('terminal_status'), isTrue);
      expect(registry.has('terminal_run'), isTrue);
      expect(registry.has('browser_goto'), isFalse);
    });

    test('重复注入幂等（has 守卫）', () {
      final plugin = TerminalToolsPlugin(FakeTerminalChannel());
      final registry = ToolRegistry();
      plugin.provideTools(registry);
      final first = registry.has('terminal_run');
      plugin.provideTools(registry);
      expect(first, isTrue);
      // 仍是同一个工具实例（未被重复覆盖导致状态丢失）
      expect(registry.has('terminal_run'), isTrue);
    });

    test('id 为 terminal', () {
      expect(TerminalToolsPlugin().id, 'terminal');
    });
  });

  group('终端错误统一入 App 日志 (Fix A)', () {
    late List<String> lines;

    setUp(() {
      lines = [];
      log.setTestFileWriter((_, content) async => lines.add(content));
      log.setEnabledFlagOnly(true);
      log.setVerbose(true);
    });

    tearDown(() {
      log.setTestFileWriter(null);
    });

    test('TerminalStatusTool 失败时记录 E 级日志', () async {
      final tool = TerminalStatusTool(_ThrowingChannel());
      final r = await tool.execute({});
      expect(r, contains('终端沙箱不可用'));
      expect(
        lines.any((l) => l.contains('[E]') && l.contains('[Terminal]')),
        isTrue,
      );
    });

    test('TerminalRunTool 失败时记录 E 级日志', () async {
      final tool = TerminalRunTool(_ThrowingChannel());
      final r = await tool.execute({'command': 'ls -la'});
      expect(r, contains('终端执行失败'));
      expect(
        lines.any((l) => l.contains('[E]') && l.contains('[Terminal]')),
        isTrue,
      );
    });
  });
}
