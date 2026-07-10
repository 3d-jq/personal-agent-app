import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/widgets/chat_bubble.dart';

void main() {
  group('ChatBubble', () {
    Widget build(ChatMessage msg, {VoidCallback? onRetry, VoidCallback? onDelete, VoidCallback? onRegenerate}) {
      return MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: Scaffold(
          body: ListView(
            children: [
              ChatBubble(
                msg: msg,
                nc: AgentColors.light(),
                onRetry: onRetry,
                onDelete: onDelete,
                onRegenerate: onRegenerate,
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('user bubble renders text', (tester) async {
      final msg = ChatMessage(text: '你好', isUser: true);
      await tester.pumpWidget(build(msg));
      expect(find.text('你好'), findsOneWidget);
    });

    testWidgets('AI bubble renders text', (tester) async {
      final msg = ChatMessage(text: '我是 DWeis', isUser: false);
      await tester.pumpWidget(build(msg));
      expect(find.text('我是 DWeis'), findsOneWidget);
    });

    testWidgets('error card shows retry and fires callback', (tester) async {
      var retried = false;
      final msg = ChatMessage(text: '网络异常', isUser: false);
      msg.isError = true;

      await tester.pumpWidget(build(msg, onRetry: () => retried = true));

      expect(find.text('网络异常'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('long-press shows action menu (copy only when no callbacks)', (tester) async {
      final msg = ChatMessage(text: '长按我', isUser: true);
      await tester.pumpWidget(build(msg));

      await tester.longPress(find.byType(ChatBubble));
      await tester.pumpAndSettle();

      expect(find.text('复制'), findsOneWidget);
      expect(find.text('删除'), findsNothing);
    });

    testWidgets('long-press menu offers regenerate + delete when callbacks provided', (tester) async {
      final msg = ChatMessage(text: 'AI 回复', isUser: false);
      await tester.pumpWidget(
        build(msg, onDelete: () {}, onRegenerate: () {}),
      );

      await tester.longPress(find.byType(ChatBubble));
      await tester.pumpAndSettle();

      expect(find.text('复制'), findsOneWidget);
      expect(find.text('重新生成'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('流式期间用纯文本渲染（markdown 标记原样显示，避免每 token 全量解析卡顿）', (tester) async {
      final msg = ChatMessage(text: '**粗**', isUser: false);
      msg.isStreaming = true;
      await tester.pumpWidget(build(msg));
      // 纯文本路径：原始 markdown 标记应直接作为文本显示
      expect(find.text('**粗**'), findsOneWidget);
      expect(find.text('粗'), findsNothing);
    });

    testWidgets('流结束后用富文本渲染（markdown 标记被解析为粗体）', (tester) async {
      final msg = ChatMessage(text: '**粗**', isUser: false);
      // isStreaming 默认 false
      await tester.pumpWidget(build(msg));
      expect(find.text('**粗**'), findsNothing);
      expect(find.text('粗'), findsOneWidget);
    });
  });
}
