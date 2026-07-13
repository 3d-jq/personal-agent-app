import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/controllers/chat_controller.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/models/chat_session.dart';
import 'package:personal_agent_app/services/chat_storage.dart';
import 'package:personal_agent_app/services/connectivity_service.dart';
import 'package:personal_agent_app/services/context_doc_service.dart';
import 'package:personal_agent_app/services/storage/app_database.dart';
import 'package:personal_agent_app/widgets/ai_settings.dart';
import 'package:personal_agent_app/widgets/vendor_config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    await resetDependencies();
    await AppDatabase.instance.initializeForTest(databaseFactoryFfi);
    await configureDependencies();

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

  test('switchSession：加载目标会话并清空旧会话消息', () async {
    final storage = FakeChatStorage();
    final controller = ChatController(chatStorage: storage);

    await controller.loadSession('sA');
    expect(controller.currentSessionId, 'sA');
    expect(controller.messages.length, 2);
    expect(controller.messages.any((m) => m.text == 'A 的消息1'), isTrue);

    // 切换到 sB：旧会话 A 的消息必须不再残留，新会话 B 就位。
    await controller.switchSession('sB');
    expect(controller.currentSessionId, 'sB');
    expect(controller.messages.length, 1);
    expect(controller.messages.first.text, 'B 的消息');
    // 旧会话 A 的消息已清空（长度从 2 变为 1），新会话 B 就位。
    expect(controller.messages.length, 1);
  });
}

/// 两个会话各带消息，用于验证 switchSession 的清空/加载。
class FakeChatStorage implements ChatStorage {
  final sA = ChatSession(
    id: 'sA',
    title: 'A',
    messages: [
      ChatMessage(text: 'A 的消息1', isUser: true),
      ChatMessage(text: 'A 的消息2', isUser: false),
    ],
    updatedAt: DateTime(2025),
  );
  final sB = ChatSession(
    id: 'sB',
    title: 'B',
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

class FakeAISettings extends AISettings {
  FakeAISettings() {
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

class FakeConnectivity extends ConnectivityService {
  @override
  Future<bool> check() async => true;
}

class FakeContextDocService extends ContextDocService {
  @override
  Future<void> ensureDefaults() async {}

  @override
  Future<void> loadAll() async {}

  @override
  String cached(ContextDoc doc) => '';

  @override
  bool hasUserProfile() => false;
}
