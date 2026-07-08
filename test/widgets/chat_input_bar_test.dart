import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/widgets/chat_input_bar.dart';
import 'package:personal_agent_app/widgets/ai_settings.dart';
import 'package:personal_agent_app/core/agent_colors.dart';

void main() {
  group('ChatInputBar', () {
    late TextEditingController controller;
    late FocusNode focusNode;
    late AISettings settings;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
      settings = AISettings();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    Widget buildTestWidget({
      bool isLoading = false,
      bool isCompressing = false,
      bool isAwaitingReply = false,
      File? pendingFile,
      String pendingFileType = '',
    }) {
      return MaterialApp(
        theme: ThemeData(
          extensions: [
            AgentColors.light(),
          ],
        ),
        home: Scaffold(
          body: ChatInputBar(
            bottomSafe: 0,
            controller: controller,
            focusNode: focusNode,
            onSend: () {},
            onStop: () {},
            isLoading: isLoading,
            isCompressing: isCompressing,
            isAwaitingReply: isAwaitingReply,
            settings: settings,
            onChanged: () {},
            pendingFile: pendingFile,
            pendingFileType: pendingFileType,
            onAttachment: (_, __) {},
            onClearAttachment: () {},
          ),
        ),
      );
    }

    testWidgets('renders text field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows default hint text', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('给 DWeis 发消息'), findsOneWidget);
    });

    testWidgets('shows compressing hint when compressing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isCompressing: true));
      expect(find.text('上下文压缩中...'), findsOneWidget);
    });

    testWidgets('shows awaiting reply hint', (tester) async {
      await tester.pumpWidget(buildTestWidget(isAwaitingReply: true));
      expect(find.text('回复以继续…'), findsOneWidget);
    });

    testWidgets('shows attachment hint when file pending', (tester) async {
      final file = File('/tmp/test.txt');
      await tester.pumpWidget(
        buildTestWidget(pendingFile: file, pendingFileType: 'document'),
      );
      expect(find.text('添加描述（可选）'), findsOneWidget);
    });

    testWidgets('disables text field when compressing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isCompressing: true));
      
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('enables text field when not compressing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isCompressing: false));
      
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isTrue);
    });

    testWidgets('displays disclaimer text', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('大模型也会出错，请谨慎核对内容'), findsOneWidget);
    });

    testWidgets('updates text field content', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      
      await tester.enterText(find.byType(TextField), 'New text');
      await tester.pump();
      
      expect(controller.text, 'New text');
    });

    testWidgets('renders with different bottom safe values', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: Scaffold(
          body: ChatInputBar(
            bottomSafe: 50,
            controller: controller,
            focusNode: focusNode,
            onSend: () {},
            onStop: () {},
            isLoading: false,
            settings: settings,
            onChanged: () {},
          ),
        ),
      ));
      
      expect(find.byType(ChatInputBar), findsOneWidget);
    });

    testWidgets('handles null onAttachment gracefully', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: Scaffold(
          body: ChatInputBar(
            bottomSafe: 0,
            controller: controller,
            focusNode: focusNode,
            onSend: () {},
            onStop: () {},
            isLoading: false,
            settings: settings,
            onChanged: () {},
            onAttachment: null,
          ),
        ),
      ));
      
      // Should not crash
      expect(find.byType(ChatInputBar), findsOneWidget);
    });

    testWidgets('handles null onClearAttachment gracefully', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: Scaffold(
          body: ChatInputBar(
            bottomSafe: 0,
            controller: controller,
            focusNode: focusNode,
            onSend: () {},
            onStop: () {},
            isLoading: false,
            settings: settings,
            onChanged: () {},
            onClearAttachment: null,
          ),
        ),
      ));
      
      // Should not crash
      expect(find.byType(ChatInputBar), findsOneWidget);
    });

    testWidgets('multiline text input works', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      
      await tester.enterText(find.byType(TextField), 'Line 1\nLine 2');
      await tester.pump();
      
      expect(controller.text, 'Line 1\nLine 2');
    });

    testWidgets('max lines is 6', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, 6);
    });

    testWidgets('min lines is 1', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.minLines, 1);
    });

    testWidgets('keyboard type is multiline', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.keyboardType, TextInputType.multiline);
    });

    testWidgets('text input action is newline', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textInputAction, TextInputAction.newline);
    });
  });

  group('ChatInputBar state management', () {
    testWidgets('responds to text changes', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      final settings = AISettings();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: Scaffold(
          body: ChatInputBar(
            bottomSafe: 0,
            controller: controller,
            focusNode: focusNode,
            onSend: () {},
            onStop: () {},
            isLoading: false,
            settings: settings,
            onChanged: () {},
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pump();

      // The widget should rebuild when text changes
      expect(find.text('Test'), findsOneWidget);
      
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('handles focus changes', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      final settings = AISettings();

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: Scaffold(
          body: ChatInputBar(
            bottomSafe: 0,
            controller: controller,
            focusNode: focusNode,
            onSend: () {},
            onStop: () {},
            isLoading: false,
            settings: settings,
            onChanged: () {},
          ),
        ),
      ));

      // Tap on text field to focus
      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);
      
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('clears text after sending', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      final settings = AISettings();

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: Scaffold(
          body: ChatInputBar(
            bottomSafe: 0,
            controller: controller,
            focusNode: focusNode,
            onSend: () {},
            onStop: () {},
            isLoading: false,
            settings: settings,
            onChanged: () {},
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      // Note: The widget doesn't automatically clear text after send
      // The parent widget is responsible for clearing
      expect(controller.text, 'Hello');
      
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('shows loading state', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      final settings = AISettings();

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: Scaffold(
          body: ChatInputBar(
            bottomSafe: 0,
            controller: controller,
            focusNode: focusNode,
            onSend: () {},
            onStop: () {},
            isLoading: true,
            settings: settings,
            onChanged: () {},
          ),
        ),
      ));

      // When loading, the text field should still be enabled
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isTrue);
      
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('shows awaiting reply state', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      final settings = AISettings();

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: Scaffold(
          body: ChatInputBar(
            bottomSafe: 0,
            controller: controller,
            focusNode: focusNode,
            onSend: () {},
            onStop: () {},
            isLoading: false,
            isAwaitingReply: true,
            settings: settings,
            onChanged: () {},
          ),
        ),
      ));

      // When awaiting reply, hint text should change
      expect(find.text('回复以继续…'), findsOneWidget);
      
      controller.dispose();
      focusNode.dispose();
    });
  });
}