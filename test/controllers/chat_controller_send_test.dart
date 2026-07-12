import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/controllers/chat_controller.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/models/chat_session.dart';
import 'package:personal_agent_app/services/ai_service_base.dart';
import 'package:personal_agent_app/services/chat_storage.dart';
import 'package:personal_agent_app/services/connectivity_service.dart';
import 'package:personal_agent_app/services/context_doc_service.dart';
import 'package:personal_agent_app/services/storage/app_database.dart';
import 'package:personal_agent_app/widgets/ai_settings.dart';
import 'package:personal_agent_app/widgets/vendor_config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late HttpClientAdapter originalAdapter;

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

    // 拦截真实 AI 网络请求，用脚本化 SSE 驱动一次正常回复
    originalAdapter = AiHttpClient.sharedDio.httpClientAdapter;
    AiHttpClient.sharedDio.httpClientAdapter = _FakeChatAdapter();
  });

  tearDown(() async {
    AiHttpClient.sharedDio.httpClientAdapter = originalAdapter;
    await resetDependencies();
  });

  test('发送消息：用户消息与 AI 回复都落进 controller.messages（回归守卫）',
      () async {
    final fake = _FakeChatStorage();
    final controller = ChatController(chatStorage: fake);

    await controller.sendMessage('你好');
    await _waitUntilDone(controller);

    // —— 回归核心 ——
    // 历史 bug：newSession() 用 `_messages = []` 重赋值，导致 MessageWindow 仍持有
    // 旧列表引用：发送的消息进了孤儿列表、controller.messages 读不到、且
    // sendMessage 里 `_messages.last` 在空列表上抛 StateError。
    // 修复后 _messages 为 final 并原地 clear，controller.messages（与窗口共享同一
    // 列表引用）必须能看到这一轮对话。
    expect(controller.messages.where((m) => m.isUser), hasLength(1));
    expect(controller.messages.length, 2);

    final aiMsg = controller.messages.last;
    expect(aiMsg.isUser, isFalse);
    expect(aiMsg.text, isNotEmpty);
    expect(aiMsg.text, contains('助手'));
    expect(aiMsg.isStreaming, isFalse);
  });
}

Future<void> _waitUntilDone(ChatController c) async {
  final sw = Stopwatch()..start();
  while (c.isLoading && sw.elapsed < const Duration(seconds: 15)) {
    await Future.delayed(const Duration(milliseconds: 20));
  }
  expect(c.isLoading, isFalse, reason: 'AI 流应在超时内完成');
}

/// 脚本化 AI 后端：返回一段 SSE 文本流，无工具调用。
class _FakeChatAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final sse = 'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'content': '你好，我是助手'}
        }
      ]
    })}\n'
        'data: [DONE]\n';
    return ResponseBody.fromString(
      sse,
      200,
      headers: {'content-type': ['text/event-stream']},
    );
  }

  @override
  void close({bool force = false}) {}
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

/// 跳过真实文件 I/O（assets/文档目录），返回空上下文。
class _FakeContextDocService extends ContextDocService {
  @override
  Future<void> loadAll() async {}

  @override
  String cached(ContextDoc doc) => '';

  @override
  bool hasUserProfile() => false;
}

class _FakeChatStorage implements ChatStorage {
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
  Future<ChatSession?> loadSession(String id,
      {int? afterSeq, int? limit, int? beforeSeq, bool full = false}) async {
    return null;
  }

  @override
  Future<void> save(ChatSession session) async {}

  @override
  Future<int> countMessages(String sessionId) async => 0;

  @override
  Future<void> deleteMessage(String sessionId, String msgId) async {}
}
