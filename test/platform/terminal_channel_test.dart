import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/platform/terminal_channel.dart';
import 'package:personal_agent_app/services/log_service.dart';

void main() {
  group('routeNativeLog (原生日志 → App 统一日志)', () {
    late List<String> lines;

    setUp(() {
      lines = [];
      // 注入内存写入器，避免真实文件 I/O；verbose 确保各等级都落盘。
      log.setTestFileWriter((_, content) async => lines.add(content));
      log.setEnabledFlagOnly(true);
      log.setVerbose(true);
    });

    tearDown(() {
      // 还原为默认（enabled=true, verbose=kDebugMode），不污染其他测试。
      log.setTestFileWriter(null);
    });

    test('E → log.e / W → log.w / 其他 → log.i', () {
      routeNativeLog('E', 'TerminalNative', 'env init failed');
      routeNativeLog('W', 'TerminalNative', 'bash symlink fallback to copy');
      routeNativeLog('D', 'TerminalNative', 'linking native libs');

      expect(
        lines.any((l) =>
            l.contains('[E]') && l.contains('[TerminalNative]') && l.contains('env init failed')),
        isTrue,
      );
      expect(
        lines.any((l) =>
            l.contains('[W]') && l.contains('[TerminalNative]') && l.contains('bash symlink fallback to copy')),
        isTrue,
      );
      expect(
        lines.any((l) =>
            l.contains('[I]') && l.contains('[TerminalNative]') && l.contains('linking native libs')),
        isTrue,
      );
    });

    test('空 message 不抛异常', () {
      expect(() => routeNativeLog('E', 'TerminalNative', ''), returnsNormally);
    });
  });
}
