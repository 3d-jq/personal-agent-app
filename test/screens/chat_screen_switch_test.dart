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
import 'package:personal_agent_app/widgets/vendor_config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    await resetDependencies();
    await AppDatabase.instance.initializeForTest(databaseFactoryFfi);
    await configureDependencies();

    final storage = _FakeChatStorage();
    if (getIt.isRegistered<ChatStorage>()) getIt.unregister<ChatStorage>();
    getIt.registerSingleton<ChatStorage>(storage);
    if (getIt.isRegistered<AISettings>()) getIt.unregister<AISettings>();
    getIt.registerSingleton<AISettings>(_FakeAISettings());
    if (getIt.isRegistered<ConnectivityService>()) {
      getIt.unregister<ConnectivityService>();
    }
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivity());
    if (getIt.isRegistered<ContextDocService>()) {
      getIt.unregister<ContextDocService>();
    }
    getIt.registerSingleton<ContextDocService>(_FakeContextDocService());
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

    // 点击会话 B：_onSessionTap 立即切到「加载对话中」骨架屏。
    await tester.tap(find.text('会话B'));
    await tester.pump(); // setState 后立即同步一帧，使 _switching=true 的骨架生效
    // 侧边栏关闭动画 + 模拟 DB 加载耗时（fake 故意延迟）期间：延迟加载生效，
    // 骨架屏持续显示「加载对话中」，switchSession 尚未完成。
    expect(find.text('加载对话中'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));

    // 切换完成后骨架屏退出动画结束，「加载对话中」消失。骨架屏 shimmer 是无限动画，
    // 故不能用 pumpAndSettle（会挂起）；改用小步长循环 pump 直到旧骨架被 AnimatedSwitcher
    // 移除（单次大跨度 pump 不会驱动动画 ticker，会导致退出动画观测不到）。
    for (var i = 0;
        i < 50 && find.text('加载对话中').evaluate().isNotEmpty;
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

/// 会话 sA / sB 各带消息，用于验证延迟切会话的端到端行为。
class _FakeChatStorage implements ChatStorage {
  final sA = ChatSession(
    id: 'sA',
    title: '会话A',
    messages: [
      ChatMessage(text: 'A 的消息1', isUser: true),
      ChatMessage(text: 'A 的消息2', isUser: false),
    ],
    updatedAt: DateTime(2025),
  );
  final sB = ChatSession(
    id: 'sB',
    title: '会话B',
    messages: [ChatMessage(text: 'B 的消息', isUser: true)],
    updatedAt: DateTime(2025),
  );

  @override
  void clearCache() {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<ChatSession>> loadAll({int? limit, int? offset}) async => [sA, sB];

  @override
  Future<List<ChatSession>> loadChatSessions({int? limit, int? offset}) async =>
      [sA, sB];

  @override
  Future<ChatSession?> loadSession(String id,
      {int? afterSeq, int? limit, int? beforeSeq, bool full = false}) async {
    // 人为放慢，模拟真实 DB 加载耗时，使「延迟加载」骨架屏在测试中可被稳定观察到
    // （否则 switchSession 在单次 pump 内瞬时完成，骨架屏一闪而过无法断言）。
    await Future.delayed(const Duration(milliseconds: 300));
    if (id == 'sA') return sA;
    if (id == 'sB') return sB;
    return null;
  }

  @override
  Future<void> save(ChatSession session) async {}

  @override
  Future<int> countMessages(String sessionId) async => 0;

  @override
  Future<void> deleteMessage(String sessionId, String msgId) async {}
}

class _FakeAISettings extends AISettings {
  _FakeAISettings() {
    vendors = [
      VendorConfig(
        id: 'v1',
        name: 'Test',
        apiKey: 'sk-test',
        baseUrl: 'https://fake.test/v1',
        model: 'test-model',
      )
    ];
    selectedVendorId = 'v1';
    thinkingEffort = 'medium';
    contextWindowSize = 256000;
  }

  @override
  Future<void> load() async {}
}

class _FakeConnectivity extends ConnectivityService {
  @override
  Future<bool> check() async => true;
}

class _FakeContextDocService extends ContextDocService {
  @override
  Future<void> ensureDefaults() async {}

  @override
  Future<void> loadAll() async {}

  @override
  String cached(ContextDoc doc) => '';

  @override
  bool hasUserProfile() => false;
}
