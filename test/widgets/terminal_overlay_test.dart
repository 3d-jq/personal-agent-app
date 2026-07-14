import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/platform/terminal_channel.dart';
import 'package:personal_agent_app/widgets/terminal_overlay.dart';
import 'package:xterm/xterm.dart';

/// 仅供本测试使用的假通道。
class _FakeChannel extends TerminalChannel {
  _FakeChannel() : super(const MethodChannel('test.terminal.overlay.fake'));
  @override
  Future<bool> ensureReady() async => true;
  @override
  Future<bool> start(String sessionId) async => true;
  @override
  Future<bool> write(String sessionId, String data) async => true;
  @override
  Future<TerminalExecResult> exec(String command, {int timeoutMs = 30000}) async =>
      const TerminalExecResult(output: '', exitCode: 0, state: 'OK', error: '');
  @override
  Future<bool> close(String sessionId) async => true;
  @override
  Stream<Uint8List> get output => const Stream<Uint8List>.empty();
}

void main() {
  testWidgets('TerminalOverlay 显示标题并渲染终端（就绪后）', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalOverlay(
            channel: _FakeChannel(),
            onClose: () => closed = true,
          ),
        ),
      ),
    );

    // 顶部标题与关闭按钮
    expect(find.text('终端沙箱'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // 等待异步初始化完成（ensureReady/start + setState）
    await tester.pumpAndSettle();

    // 就绪后渲染 xterm TerminalView
    expect(find.byType(TerminalView), findsOneWidget);

    // 点击关闭回调
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(closed, isTrue);
  });
}
