import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/widgets/session_info_button.dart';

/// 放大视口以容纳固定高度的面板（真机屏幕够高，面板不滚动、一次性全显示）。
Future<void> _pumpWithLargeViewport(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(widget);
  addTearDown(() {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 3.0;
  });
}

void main() {
  testWidgets('点击身份牌弹出会话信息面板，含上下文占用与文档入口', (tester) async {
    final nc = AgentColors.light();
    await _pumpWithLargeViewport(
      tester,
      MaterialApp(
        theme: ThemeData(extensions: [nc]),
        home: Scaffold(
          body: SessionInfoButton(
            getTokens: () => 12345,
            getWindowSize: () => 256000,
            getThreshold: () => 204800,
          ),
        ),
      ),
    );

    // 顶部身份牌按钮存在
    expect(find.byIcon(Icons.badge), findsOneWidget);

    // 点击弹出面板
    await tester.tap(find.byIcon(Icons.badge));
    await tester.pumpAndSettle();

    // 面板标题 + 上下文占用卡片
    expect(find.text('会话信息'), findsOneWidget);
    expect(find.text('上下文窗口占用'), findsOneWidget);
    // 数字格式：一位小数（几百 token 变化也可见），约 12.3K / 256K
    expect(find.text('约 12.3K / 256K'), findsOneWidget);
    // 占用正常（绿态文案）
    expect(find.text('占用正常'), findsOneWidget);

    // 原文档入口保留
    expect(find.text('AI 草稿纸'), findsOneWidget);
  });

  testWidgets('占用接近阈值时显示红态文案', (tester) async {
    final nc = AgentColors.light();
    await _pumpWithLargeViewport(
      tester,
      MaterialApp(
        theme: ThemeData(extensions: [nc]),
        home: Scaffold(
          body: SessionInfoButton(
            getTokens: () => 250000,
            getWindowSize: () => 256000,
            getThreshold: () => 204800,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.badge));
    await tester.pumpAndSettle();
    expect(find.text('接近压缩阈值，即将自动压缩'), findsOneWidget);
  });
}
