import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/controllers/chat_controller.dart';
import 'package:personal_agent_app/controllers/message_window.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/models/chat_session.dart';
import 'package:personal_agent_app/services/chat_storage.dart';
import 'package:personal_agent_app/services/connectivity_service.dart';
import 'package:personal_agent_app/services/context_doc_service.dart';
import 'package:personal_agent_app/widgets/ai_settings.dart';
import 'package:personal_agent_app/widgets/vendor_config.dart';

/// 验证「UI 视口窗口（30 条，为加载性能）」与「模型上下文（全量历史）」彻底解耦：
/// 界面只加载显示 30 条，但发送给大模型的视图必须包含全部历史，才能按 80% 阈值压缩。
void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await resetDependencies();
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

  test('MessageWindow：UI 窗口 30 与全量历史解耦（loadFullHistory 取全量）', () async {
    final storage = _FakeBigStorage();
    final messages = <ChatMessage>[];
    final window = MessageWindow(storage, messages, () {});
    window.bindSession('big');
    await window.load();

    // UI 内存窗口只装 30 条（最近 windowSize 条），并非全量历史。
    expect(messages.length, MessageWindow.windowSize);
    expect(messages.length, lessThan(_FakeBigStorage.total));

    // 但全量历史可独立取到，专供模型上下文使用——两者互不影响。
    final full = await window.loadFullHistory();
    expect(full.length, _FakeBigStorage.total - 1); // 全量视图少一条最新（模拟未落盘）
  });

  test('ChatController.buildSendView：模型看到全量历史，UI 窗口 30 不参与', () async {
    final storage = _FakeBigStorage();
    final controller = ChatController(chatStorage: storage);
    await controller.loadSession('big');

    // 界面视图仍只有窗口 30 条。
    expect(controller.messages.length, MessageWindow.windowSize);

    // 但发送给大模型的视图必须包含全部历史（全量 + 窗口中尚未落盘的最新消息）。
    final sendView = await controller.buildSendView();
    expect(sendView.length, _FakeBigStorage.total);
    // 未落盘的最新消息（seq 99）被合并进发送视图，模型不会漏看。
    expect(sendView.any((m) => m.seq == 99), isTrue);
  });
}

/// 一个长会话（100 条历史）的假存储，严格区分「UI 窗口加载」与「全量加载」：
/// - limit 非 null（UI 窗口）：返回最近 windowSize 条（含未落盘的最新一条 seq99）。
/// - full=true（模型上下文）：返回全量，但故意少一条最新（模拟「刚发的消息还没落盘」），
///   以验证发送视图会把内存中尚未落盘的消息合并回去。
class _FakeBigStorage implements ChatStorage {
  static const int total = 100;

  List<ChatMessage> _all() => [
        for (var i = 0; i < total; i++)
          ChatMessage(text: 'm$i', isUser: i.isEven)..seq = i,
      ];

  @override
  Future<ChatSession?> loadSession(String id,
      {int? afterSeq, int? limit, int? beforeSeq, bool full = false}) async {
    final all = _all();
    if (full) {
      // 全量视图：少一条最新（seq 99 尚未落盘）。
      return ChatSession(
        id: id,
        title: id,
        messages: all.sublist(0, total - 1),
        updatedAt: DateTime(2025),
      );
    }
    if (limit != null) {
      // UI 窗口：最近 limit 条（含未落盘的 seq 99）。
      final start = all.length > limit ? all.length - limit : 0;
      return ChatSession(
        id: id,
        title: id,
        messages: all.sublist(start),
        updatedAt: DateTime(2025),
      );
    }
    return ChatSession(id: id, title: id, messages: all, updatedAt: DateTime(2025));
  }

  @override
  void clearCache() {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<ChatSession>> loadAll({int? limit, int? offset}) async =>
      [ChatSession(id: 'big', title: 'big', messages: _all(), updatedAt: DateTime(2025))];

  @override
  Future<List<ChatSession>> loadChatSessions({int? limit, int? offset}) async =>
      [ChatSession(id: 'big', title: 'big', messages: _all(), updatedAt: DateTime(2025))];

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
  @override
  bool get isFirstMeeting => true;
}
