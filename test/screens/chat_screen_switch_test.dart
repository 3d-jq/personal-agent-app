import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/models/chat_session.dart';
import 'package:personal_agent_app/screens/chat_screen.dart';
import 'package:personal_agent_app/services/chat_controller_cache.dart';
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

    final storage = FakeChatStorage(sessions: [_sA, _sB], loadDelay: const Duration(milliseconds: 300));
    if (getIt.isRegistered<ChatStorage>()) getIt.unregister<ChatStorage>();
    getIt.registerSingleton<ChatStorage>(storage);
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

  testWidgets(
      '侧边栏点击对话：先看「加载对话中」骨架，侧边栏关闭后才切到目标会话',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: const ChatScreen(sessionId: 'sA'),
      ),
    );
    // 进入 sA：控制器已就绪，直接显示真实列表，无冷启动骨架。
    await tester.pumpAndSettle();
    expect(find.text('加载对话中'), findsNothing);

    // 打开平推侧边栏：点击顶栏菜单按钮（Icons.list）。
    await tester.tap(find.byIcon(Icons.list));
    await tester.pumpAndSettle();

    // 点击会话 B：侧边栏先关，关完才出骨架屏。
    await tester.tap(find.text('会话B'));
    await tester.pump(); // 让 tap 处理完成，sideBarCtrl 开始 reverse
    // 侧边栏关闭动画 300ms，小步 pump 驱动 AnimationController tick
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 150)); // 总共 350ms，动画完成
    // 侧边栏关完→骨架屏出现
    expect(find.text('加载对话中'), findsOneWidget);

    // 模拟 DB 加载耗时（fake 故意延迟 300ms），骨架屏持续显示。
    // 骨架屏 shimmer 是无限动画，不能用 pumpAndSettle（会挂起），小步循环 pump。
    for (var i = 0;
        i < 30 && find.text('加载对话中').evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // 切换完成后骨架屏消失。
    expect(find.text('加载对话中'), findsNothing);

    // 控制器确实切到了 sB。
    final controller = getIt<ChatControllerCache>().obtain('sA');
    expect(controller.currentSessionId, 'sB');
  });
}

// ── 测试数据 ──────────────────────────────────────────────────────────

final _sA = ChatSession(
  id: 'sA',
  title: '会话A',
  messages: [
    ChatMessage(text: 'A 的消息1', isUser: true),
    ChatMessage(text: 'A 的消息2', isUser: false),
  ],
  updatedAt: DateTime(2025),
);
final _sB = ChatSession(
  id: 'sB',
  title: '会话B',
  messages: [ChatMessage(text: 'B 的消息', isUser: true)],
  updatedAt: DateTime(2025),
);
