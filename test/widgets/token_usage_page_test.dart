import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/services/token_usage_tracker.dart';
import 'package:personal_agent_app/widgets/common_widgets.dart';
import 'package:personal_agent_app/widgets/token_usage_page.dart';

/// mock path_provider 通道，避免 Windows 下挂起；同时让保存落到临时目录。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tmp.path;
      }
      return null;
    },
  );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tok_page_');
    tokenTracker.resetForTest();
  });

  tearDown(() {
    tokenTracker.resetForTest();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: Builder(builder: (c) => const TokenUsagePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('空状态：显示「暂无 token 统计」', (tester) async {
    await pumpPage(tester);
    expect(find.text('Token 消耗统计'), findsOneWidget);
    expect(find.text('暂无 token 统计'), findsOneWidget);
    // 空状态时无重置按钮、无汇总卡。
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('消耗汇总'), findsNothing);
  });

  testWidgets('有数据：显示汇总卡/分布/模型明细', (tester) async {
    tokenTracker.record(
      vendor: 'OpenAI',
      model: 'gpt-4o',
      inputTokens: 1_000_000,
      outputTokens: 500_000,
      cachedInputTokens: 200_000,
    );
    await pumpPage(tester);

    expect(find.text('消耗汇总'), findsOneWidget);
    expect(find.text('模型用量分布'), findsOneWidget);
    expect(find.text('模型明细'), findsOneWidget);
    // 模型名与厂商出现在模型卡。
    expect(find.text('gpt-4o'), findsWidgets);
    // 模型卡初始在视口下方（off-stage），find.text 默认跳过，故显式包含。
    expect(find.text('OpenAI', skipOffstage: false), findsWidgets);
    // 汇总卡含总成本（¥）与请求次数。
    expect(find.text('总成本'), findsOneWidget);
    expect(find.text('请求次数'), findsOneWidget);
    // 冲刷防抖保存定时器（record 后 300ms 落盘），避免测试结束时仍有挂起定时器。
    await tester.pump(const Duration(milliseconds: 350));
  });

  testWidgets('点击模型卡 → 编辑单价弹窗 → 切「按次」并保存', (tester) async {
    tokenTracker.record(
      vendor: 'OpenAI',
      model: 'gpt-4o',
      inputTokens: 1000,
      outputTokens: 500,
    );
    await pumpPage(tester);

    // 打开编辑弹窗：模型名同时出现在卡片与分布行，点「被 InkWell 包裹」的卡片文本。
    final card = find.ancestor(
      of: find.text('gpt-4o'),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(card.first);
    await tester.pumpAndSettle();
    await tester.tap(card.first);
    await tester.pumpAndSettle();
    expect(find.text('编辑单价 · gpt-4o'), findsOneWidget);

    // 切到「按次」计费，单价字段随模式变化。
    await tester.tap(find.text('按次'));
    await tester.pumpAndSettle();
    expect(find.text('每次请求价 (¥)'), findsOneWidget);

    // 保存（弹窗内的 TextButton）。
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    final price = tokenTracker.priceOf('OpenAI~gpt-4o');
    expect(price, isNotNull);
    expect(price?.mode, BillingMode.count);
  });

  testWidgets('重置全部：弹窗确认后回到空状态', (tester) async {
    tokenTracker.record(
      vendor: 'OpenAI',
      model: 'gpt-4o',
      inputTokens: 1000,
      outputTokens: 500,
    );
    await pumpPage(tester);
    expect(find.text('消耗汇总'), findsOneWidget);

    // 顶部 AppBar 的清空按钮（模型卡里也有一个 delete_outline，须精确到 AppTopBar 内）。
    final appBarReset = find.descendant(
      of: find.byType(AppTopBar),
      matching: find.byIcon(Icons.delete_outline),
    );
    await tester.tap(appBarReset);
    await tester.pumpAndSettle();
    expect(find.text('清空全部统计'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '清空'));
    await tester.pumpAndSettle();

    expect(find.text('暂无 token 统计'), findsOneWidget);
  });
}
