import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LogService service;
  final captured = <String>[];

  // flutter test 下 getApplicationDocumentsDirectory 走 MethodChannel 且无默认
  // handler（报 MissingPluginException）。mock 返回系统临时目录，使 recordFatal
  // 的 _ensureFilePath 能拿到路径而不报错（仅设置路径，不实际写盘）。
  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    });
  });

  setUp(() {
    service = LogService();
    captured.clear();
    // 注入纯内存写入器：捕获所有写盘内容，彻底避免 flutter test 下真实文件 I/O
    // 在 Windows 上偶发卡死（杀软拦截）的问题。
    service.setTestFileWriter((path, content) async {
      captured.add(content);
    });
  });

  group('LogService 崩溃留痕（纯内存，无真实 I/O）', () {
    testWidgets('recordFatal 即使关闭也写入崩溃信息', (tester) async {
      service.setEnabledFlagOnly(false);
      await service.recordFatal(
          'Uncaught zone error', Exception('boom'), StackTrace.current);
      await tester.pump();
      expect(captured, isNotEmpty);
      expect(captured.first, contains('boom'));
      expect(captured.first, contains('[F]'));
      expect(captured.first, contains('Uncaught zone error'));
    });

    testWidgets('关闭状态下普通日志不写盘', (tester) async {
      service.setEnabledFlagOnly(false);
      service.i('TestTag', 'should-not-be-written');
      await tester.pump();
      expect(captured, isEmpty);
    });

    testWidgets('开启后普通日志带日期时间戳写入', (tester) async {
      service.setEnabledFlagOnly(true);
      service.i('TestTag', 'hello-world');
      await tester.pump();
      expect(captured, isNotEmpty);
      final line = captured.first;
      expect(line, contains('hello-world'));
      expect(line, contains('[I]'));
      expect(line,
          matches(RegExp(r'\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\]')));
    });
  });
}
