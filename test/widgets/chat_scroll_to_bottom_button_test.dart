import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/widgets/chat_scroll_to_bottom_button.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [AgentColors.light()]),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('ChatScrollToBottomButton', () {
    testWidgets('无未读：圆形按钮最小尺寸 36×36（修复被压成图标大小的回归）',
        (tester) async {
      await tester.pumpWidget(_wrap(ChatScrollToBottomButton(
        unread: 0,
        onTap: () {},
      )));
      final size = tester.getSize(find.byType(ChatScrollToBottomButton));
      expect(size.width, greaterThanOrEqualTo(36));
      expect(size.height, greaterThanOrEqualTo(36));
      // 无未读时不显示「N 条新消息」文案
      expect(find.textContaining('条新消息'), findsNothing);
    });

    testWidgets('有未读：显示「N 条新消息」胶囊且可点击', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(ChatScrollToBottomButton(
        unread: 5,
        onTap: () => tapped = true,
      )));
      expect(find.text('5 条新消息'), findsOneWidget);
      await tester.tap(find.byType(ChatScrollToBottomButton));
      expect(tapped, isTrue);
    });
  });
}
