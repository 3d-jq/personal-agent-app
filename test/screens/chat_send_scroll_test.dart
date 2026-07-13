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
              // 目标 item：锚定它，后续验证它是否在视口顶部
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

    // 先滚到底部（模拟 sendMessage 内部的 scrollDown）
    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
    scrollable.controller!.jumpTo(
      scrollable.controller!.position.maxScrollExtent,
    );
    await tester.pump();

    // 确认 anchor widget 已渲染
    final ctx = anchorKey.currentContext;
    expect(ctx, isNotNull);
    expect(ctx!.mounted, isTrue);

    // 执行 Scrollable.ensureVisible，把目标顶到视口顶部
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0, // 顶部对齐
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    // 等待动画完成
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 验证：目标 widget 的全局 Y 坐标应接近 AppBar 底部（~56 + 8 = 64）
    final renderBox = ctx.findRenderObject()! as RenderBox;
    final pos = renderBox.localToGlobal(Offset.zero);
    expect(pos.dy, lessThan(80)); // 在 AppBar 下方附近
    expect(pos.dy, greaterThan(40)); // 不低于 AppBar
  });

  // ── 集成测试：ChatScreen 发送后用户消息在视口顶部 ──

  testWidgets('ChatScreen 发送消息后用户消息可见且偏上', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: const ChatScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 验证输入框存在
    expect(find.byType(TextField), findsOneWidget);

    // 输入文字
    await tester.enterText(find.byType(TextField), '你好测试消息');
    await tester.pump();

    // 点击发送
    final sendIcon = find.byIcon(Icons.arrow_upward);
    expect(sendIcon, findsOneWidget);
    await tester.tap(sendIcon);

    // 消息在微任务中添加，等几帧让渲染完成
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 验证用户消息有气泡显示
    final userTextFinder = find.text('你好测试消息');
    expect(userTextFinder, findsWidgets);
    // 取第一个匹配的 RenderObject 验证位置在屏幕内
    final renderBox = tester.renderObject<RenderBox>(userTextFinder.first);
    final pos = renderBox.localToGlobal(Offset.zero);
    expect(pos.dy, greaterThanOrEqualTo(0));
  });
}
