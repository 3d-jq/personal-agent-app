import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/error_handler.dart';

void main() {
  group('ErrorHandler', () {
    late FlutterExceptionHandler? original;

    setUp(() {
      original = FlutterError.onError;
    });

    tearDown(() {
      FlutterError.onError = original;
    });

    test('init replaces FlutterError.onError', () {
      ErrorHandler.init();
      expect(FlutterError.onError, isNotNull);
    });

    testWidgets('buildErrorWidget renders fallback UI', (
      WidgetTester tester,
    ) async {
      final details = FlutterErrorDetails(exception: Exception('boom'));
      final widget = ErrorHandler.buildErrorWidget(details);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      expect(find.text('页面出错了'), findsOneWidget);
      expect(find.text('请重启应用或返回上一页重试。'), findsOneWidget);
      if (kDebugMode) {
        expect(find.textContaining('boom'), findsOneWidget);
      }
    });
  });
}
