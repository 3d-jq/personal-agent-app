import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/services/theme_service.dart';
import 'package:personal_agent_app/widgets/chat_bubble.dart';

void main() {
  setUp(() {
    getIt.registerSingleton<ThemeService>(ThemeService());
  });
  tearDown(() {
    getIt.reset();
  });
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

    testWidgets('流式期间也渲染富文本（粗体被解析，而非纯文本）', (tester) async {
      final msg = ChatMessage(text: '这是 **粗体** 示例', isUser: false);
      msg.isStreaming = true;
      await tester.pumpWidget(build(msg));
      // 富文本路径：MarkdownBody 存在（纯文本 Text 路径不会有）
      expect(find.byType(MarkdownBody), findsWidgets);
      // 原始 markdown 围栏/标记不应以纯文本整体呈现（粗体被解析）
      expect(find.text('这是 **粗体** 示例'), findsNothing);
    });

    testWidgets('流式期间代码块即时富文本化（带复制按钮，而非纯文本）', (tester) async {
      final msg = ChatMessage(
        text: '看代码：\n```\nprint("hi")\n```\n结束',
        isUser: false,
      );
      msg.isStreaming = true;
      await tester.pumpWidget(build(msg));
      expect(find.byType(MarkdownBody), findsWidgets);
      // CodeBlockBuilder 渲染了「复制」按钮 → 证明代码块已富文本化
      expect(find.text('复制'), findsWidgets);
      // 围栏标记本身不应以纯文本出现
      expect(find.text('```'), findsNothing);
    });

    testWidgets('流结束后用富文本渲染（markdown 标记被解析为粗体）', (tester) async {
      final msg = ChatMessage(text: '**粗**', isUser: false);
      // isStreaming 默认 false
      await tester.pumpWidget(build(msg));
      expect(find.text('**粗**'), findsNothing);
      expect(find.text('粗'), findsOneWidget);
    });

    testWidgets('流式首帧空文本不抛异常（占位 text="" isStreaming=true）', (tester) async {
      // 复现真机「发消息瞬间红屏闪一下再恢复」：AI 占位消息创建时
      // text='' 且 isStreaming=true，首帧走 _rebuildStreaming 会得到空 blocks，
      // 旧实现对空列表执行 List.length=-1 → RangeError 红屏；修复后直接返回
      // 空列表，由「思考中」占位，构建无异常。
      final msg = ChatMessage(text: '', isUser: false);
      msg.isStreaming = true;
      await tester.pumpWidget(build(msg));
      expect(tester.takeException(), isNull);
      expect(find.byType(ChatBubble), findsOneWidget);
    });
  });
}
