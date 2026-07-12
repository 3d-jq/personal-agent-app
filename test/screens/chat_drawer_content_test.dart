import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/controllers/chat_controller.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/models/chat_session.dart';
import 'package:personal_agent_app/screens/chat_drawer_content.dart';
import 'package:personal_agent_app/services/chat_storage.dart';
import 'package:personal_agent_app/widgets/agent_side_drawer.dart';
import 'package:personal_agent_app/services/storage/app_database.dart';
import 'package:personal_agent_app/widgets/ai_settings.dart';
import 'package:personal_agent_app/widgets/vendor_config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late ChatController controller;

  setUp(() async {
    await resetDependencies();
    await AppDatabase.instance.initializeForTest(databaseFactoryFfi);
    await configureDependencies();

    final fakeStorage = _FakeChatStorage()
      ..sessions = [
        ChatSession(
          id: 's1',
          title: '会话标题A',
          messages: const [],
          updatedAt: DateTime(2025),
        ),
      ];
    final fakeSettings = _FakeAISettings();
    controller = ChatController(chatStorage: fakeStorage, aiSettings: fakeSettings);
    await controller.refreshSessions();
  });

  tearDown(() async => await resetDependencies());

  testWidgets('抽屉内容渲染：会话列表 + 模型胶囊', (tester) async {
    final tapped = <String>[];
    var newChatCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: Scaffold(
          body: ChatDrawerContent(
            controller: controller,
            onSessionTap: tapped.add,
            onNewChat: () => newChatCount++,
            onSessionDeleted: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(ChatDrawerContent), findsOneWidget);
    // 会话标题进入列表
    expect(find.text('会话标题A'), findsOneWidget);
    // 实际渲染的抽屉容器
    expect(find.byType(AgentSideDrawer), findsOneWidget);
  });

  testWidgets('点击会话触发 onSessionTap 回调', (tester) async {
    final tapped = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: Scaffold(
          body: ChatDrawerContent(
            controller: controller,
            onSessionTap: tapped.add,
            onNewChat: () {},
            onSessionDeleted: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('会话标题A'));
    await tester.pumpAndSettle();
    expect(tapped, contains('s1'));
  });
}

class _FakeChatStorage implements ChatStorage {
  List<ChatSession> sessions = [];

  @override
  void clearCache() {}

  @override
  Future<void> delete(String id) async =>
      sessions.removeWhere((s) => s.id == id);

  @override
  Future<List<ChatSession>> loadAll({int? limit, int? offset}) async =>
      sessions;

  @override
  Future<List<ChatSession>> loadChatSessions({int? limit, int? offset}) async =>
      sessions;

  @override
  Future<ChatSession?> loadSession(String id,
      {int? afterSeq, int? limit, int? beforeSeq, bool full = false}) async {
    return sessions.where((s) => s.id == id).firstOrNull;
  }

  @override
  Future<void> save(ChatSession session) async {
    final idx = sessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      sessions[idx] = session;
    } else {
      sessions.add(session);
    }
  }

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
