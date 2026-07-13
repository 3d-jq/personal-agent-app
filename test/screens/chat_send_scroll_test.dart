import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/screens/chat_screen.dart';
import 'package:personal_agent_app/services/chat_storage.dart';
import 'package:personal_agent_app/services/connectivity_service.dart';
import 'package:personal_agent_app/services/context_doc_service.dart';
import 'package:personal_agent_app/services/storage/app_database.dart';
import 'package:personal_agent_app/widgets/ai_settings.dart';
import 'package:personal_agent_app/widgets/chat_bubble.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../fakes/fake_chat_storage.dart';
import '../fakes/fake_ai_settings.dart';
import '../fakes/fake_connectivity.dart';
import '../fakes/fake_context_doc_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    await resetDependencies();
    await AppDatabase.instance.initializeForTest(databaseFactoryFfi);
    await configureDependencies();

    if (getIt.isRegistered<ChatStorage>()) getIt.unregister<ChatStorage>();
    getIt.registerSingleton<ChatStorage>(FakeChatStorage());

    if (getIt.isRegistered<AISettings>()) getIt.unregister<AISettings>();
    getIt.registerSingleton<AISettings>(FakeAISettings());

    if (getIt.isRegistered<ConnectivityService>()) {
      getIt.unregister<ConnectivityService>();
    }
    getIt.registerSingleton<ConnectivityService>(FakeConnectivity());

    if (getIt.isRegistered<ContextDocService>()) {
      getIt.unregister<ContextDocService>();
    }
    getIt.registerSingleton<ContextDocService>(FakeContextDocService());
  });

  tearDown(() async => await resetDependencies());

  // ── 机制测试：GlobalKey + Scrollable.ensureVisible ──

  testWidgets(
      'GlobalKey + Scrollable.ensureVisible(alignment:0) 将目标 widget 滚到视口顶部',
      (tester) async {
    final anchorKey = GlobalKey();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Test')),
        body: ListView.builder(
          itemCount: 15,
          itemBuilder: (context, i) {
            if (i == 8) {
              return RepaintBoundary(
                key: anchorKey,
                child: Container(
                  height: 100,
                  color: Colors.blue.withValues(alpha: 0.2),
                  child: const Text('TARGET'),
                ),
              );
            }
            return Container(
              height: 120,
              color: i.isEven ? Colors.grey.shade100 : Colors.grey.shade200,
              child: Text('Item $i'),
            );
          },
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // 先滚到底部
    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
    scrollable.controller!.jumpTo(
      scrollable.controller!.position.maxScrollExtent,
    );
    await tester.pump();

    final ctx = anchorKey.currentContext;
    expect(ctx, isNotNull);
    expect(ctx!.mounted, isTrue);

    Scrollable.ensureVisible(ctx, alignment: 0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final renderBox = ctx.findRenderObject()! as RenderBox;
    final pos = renderBox.localToGlobal(Offset.zero);
    expect(pos.dy, lessThan(80));
    expect(pos.dy, greaterThan(40));
  });

  // ── 集成测试：ChatScreen 发送后用户消息在视口顶部 ──

  testWidgets('发送消息后用户消息在视口顶部区域', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: const ChatScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    // 发送一条消息
    await tester.enterText(find.byType(TextField), '测试顶部');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));

    // 等滚动动画完成
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 验证：用户消息在 widget 树中可见
    final msgFinder = find.text('测试顶部');
    expect(msgFinder, findsWidgets);

    // 用 ChatBubble 中的文字做位置验证（排除输入框中的同文匹配）
    final bubbleText = find.descendant(
      of: find.byType(ChatBubble),
      matching: find.text('测试顶部'),
    );
    expect(bubbleText, findsOneWidget,
        reason: '消息应出现在 ChatBubble 中');

    final renderBox = tester.renderObject<RenderBox>(bubbleText);
    final pos = renderBox.localToGlobal(Offset.zero);
    final screenH =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    // 在屏幕上半部分（30% 以内）
    expect(pos.dy, lessThan(screenH * 0.30),
        reason: '用户消息应在视口顶部，实际 Y=${pos.dy}');
  });

  // ── 未读计数不显示 ──

  testWidgets('发送后不显示未读计数', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: const ChatScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '你好');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 不应该出现「条新消息」文字
    expect(find.textContaining('条新消息'), findsNothing);
    expect(find.textContaining('新消息'), findsNothing);
  });
}
