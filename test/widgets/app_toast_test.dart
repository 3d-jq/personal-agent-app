import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/widgets/app_toast.dart';

void main() {
  group('AppToast', () {
    testWidgets('shows message and auto-dismisses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AgentColors.light()]),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => AppToast.show(context, '已复制'),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump(); // 入场动画

      expect(find.text('已复制'), findsOneWidget);

      // 文字不应带下划线，避免某些 Android 设备/主题出现黄色下划线装饰
      final textWidget = tester.widget<Text>(find.text('已复制'));
      expect(textWidget.style?.decoration, TextDecoration.none);
      expect(textWidget.style?.decorationColor, Colors.transparent);

      // 默认 2s 后自动消失
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('已复制'), findsNothing);
    });

    testWidgets('success type renders with check icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AgentColors.light()]),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    AppToast.show(context, '已保存', type: ToastType.success),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pumpAndSettle();

      expect(find.text('已保存'), findsOneWidget);

      // 让自动消失计时器跑完，避免遗留 pending timer
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });
}
