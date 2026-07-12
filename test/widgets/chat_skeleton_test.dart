import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/widgets/chat_skeleton.dart';

void main() {
  testWidgets('无 label 时只显示气泡骨架，不出现加载说明', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: const Scaffold(body: ChatListSkeleton()),
      ),
    );
    expect(find.byType(ChatListSkeleton), findsOneWidget);
    expect(find.text('加载对话中'), findsNothing);
  });

  testWidgets('传入 label 时中央显示加载说明', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: const Scaffold(
          body: ChatListSkeleton(label: '加载对话中'),
        ),
      ),
    );
    expect(find.text('加载对话中'), findsOneWidget);
  });
}
