import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/widgets/context_usage_bar.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(extensions: [AgentColors.light()]),
      home: Scaffold(body: child),
    );

void main() {
  group('ContextUsageBar', () {
    testWidgets('标签按 K 格式化', (tester) async {
      await tester.pumpWidget(_wrap(const ContextUsageBar(
        tokens: 42000,
        windowSize: 256000,
        threshold: 204800,
      )));
      expect(find.text('42K / 256K'), findsOneWidget);
    });

    testWidgets('未到阈值时标签为 success 色', (tester) async {
      await tester.pumpWidget(_wrap(const ContextUsageBar(
        tokens: 10000,
        windowSize: 256000,
        threshold: 204800,
      )));
      final t = tester.widget<Text>(find.text('10K / 256K'));
      expect(t.style!.color, AgentColors.light().success);
    });

    testWidgets('达到阈值时标签为 error 色', (tester) async {
      await tester.pumpWidget(_wrap(const ContextUsageBar(
        tokens: 205000,
        windowSize: 256000,
        threshold: 204800,
      )));
      final t = tester.widget<Text>(find.text('205K / 256K'));
      expect(t.style!.color, AgentColors.light().error);
    });

    testWidgets('接近阈值时为 warning 色', (tester) async {
      await tester.pumpWidget(_wrap(const ContextUsageBar(
        tokens: 180000, // 0.70，介于 0.6 与阈值 0.8 之间
        windowSize: 256000,
        threshold: 204800,
      )));
      final t = tester.widget<Text>(find.text('180K / 256K'));
      expect(t.style!.color, AgentColors.light().warning);
    });

    testWidgets('showLabel=false 时不显示标签', (tester) async {
      await tester.pumpWidget(_wrap(const ContextUsageBar(
        tokens: 10000,
        windowSize: 256000,
        threshold: 204800,
        showLabel: false,
      )));
      expect(find.text('10K / 256K'), findsNothing);
    });
  });
}
