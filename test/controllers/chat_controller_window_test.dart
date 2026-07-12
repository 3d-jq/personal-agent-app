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

/// 验证 ChatController 的窗口翻页 getters/methods 正确转发到 MessageWindow。
void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    await resetDependencies();
    await AppDatabase.instance.initializeForTest(databaseFactoryFfi);
    await configureDependencies();
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

  tearDown(() async {
    await resetDependencies();
  });

  test('窗口 getters/翻页转发：load 尾部最新 20、hasOlder=true/hasNewer=false、翻页正确',
      () async {
    final fake = _FakeChatStorage();
    final c = ChatController(
      aiSettings: _FakeAISettings(),
      chatStorage: fake,
    );
    await c.loadSession('s1');

    // 初始即尾部最新页
    expect(c.canPageMessages, isTrue);
    expect(c.hasOlderMessages, isTrue); // 100 条会话，前面还有更早
    expect(c.hasNewerMessages, isFalse); // 已是最新页
    expect(c.visibleMessages.length, 20);
    expect(c.visibleMessages.last.seq, 99);

    // 往下翻一页（更老）：转发到 MessageWindow.loadOlder
    await c.loadOlderMessages();
    expect(c.visibleMessages.length, 20);
    expect(c.visibleMessages.first.seq, 60); // 更老一页（seq 60..79）
    expect(c.hasNewerMessages, isTrue); // 现在后面有更新可翻

    // 往上翻回最新页：转发到 MessageWindow.loadNewer
    await c.loadNewerMessages();
    expect(c.visibleMessages.last.seq, 99); // 回到最新页
    expect(c.hasNewerMessages, isFalse);
  });
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
  Future<void> loadAll() async {}

  @override
  String cached(ContextDoc doc) => '';

  @override
  bool hasUserProfile() => false;
}

/// 支持游标分页的脚本化存储（与真实 ChatStorage 的「正序契约」一致）。
class _FakeChatStorage implements ChatStorage {
  final Map<String, List<ChatMessage>> store = {
    's1': [
      for (int i = 0; i < 100; i++)
        ChatMessage(text: 'm$i', isUser: false)..seq = i,
    ],
  };

  @override
  void clearCache() {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<ChatSession>> loadAll({int? limit, int? offset}) async => [];

  @override
  Future<List<ChatSession>> loadChatSessions({int? limit, int? offset}) async =>
      [];

  @override
  Future<ChatSession?> loadSession(
    String id, {
    int? afterSeq,
    int? limit,
    int? beforeSeq,
    bool full = false,
  }) async {
    final all = store[id] ?? <ChatMessage>[];
    List<ChatMessage> selected;
    if (beforeSeq != null) {
      final older = all.where((m) => m.seq < beforeSeq).toList();
      final take = limit ?? older.length;
      selected =
          older.length <= take ? older : older.sublist(older.length - take);
    } else if (afterSeq != null) {
      final newer = all.where((m) => m.seq > afterSeq).toList();
      final take = limit ?? newer.length;
      selected = newer.take(take).toList();
    } else {
      final take = limit ?? all.length;
      selected = all.length <= take ? all : all.sublist(all.length - take);
    }
    return ChatSession(
      id: id,
      title: '',
      messages: selected,
      updatedAt: DateTime(2025),
    );
  }

  @override
  Future<void> save(ChatSession session) async {
    store[session.id] = session.messages;
  }

  @override
  Future<int> countMessages(String sessionId) async =>
      store[sessionId]?.length ?? 0;

  @override
  Future<void> deleteMessage(String sessionId, String msgId) async {}
}
