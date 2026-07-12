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

  test('ask_user：被问的问题对用户在气泡里可见（回归守卫）', () async {
    // 用会先返回 tool_calls（含一段前置正文，触发打字机计时器）的假后端
    // 覆盖默认 SSE 适配器——这正是旧 bug 的触发路径：打字机定时器会周期覆盖
    // aiMsg.text，把只写进 state.buf、没写进 state.typewriter 的问题覆盖掉。
    AiHttpClient.sharedDio.httpClientAdapter = _FakeAskUserAdapter();

    final controller = ChatController(chatStorage: _FakeChatStorage());

    // 不 await：sendMessage 内部订阅流后即返回，ask_user 会在流里阻塞等待用户回复。
    controller.sendMessage('帮我选个水果');

    // 等待控制器进入「等待用户输入」状态（即 _onAskUser 已执行并写入问题）。
    final sw = Stopwatch()..start();
    while (!controller.isWaitingUserPrompt &&
        sw.elapsed < const Duration(seconds: 15)) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    expect(controller.isWaitingUserPrompt, isTrue,
        reason: '应进入等待用户输入状态');

    final aiMsg = controller.messages.last;
    expect(aiMsg.isUser, isFalse);
    // —— 回归核心：被问的问题必须出现在可见气泡文本里 ——
    // 修复前打字机定时器会把它覆盖掉，用户根本看不到模型在问什么。
    expect(aiMsg.text, contains('你喜欢苹果还是香蕉？'));

    // 用户回复后，流程应继续并完成。
    controller.submitUserPromptResponse('苹果');
    final sw2 = Stopwatch()..start();
    while (controller.isLoading && sw2.elapsed < const Duration(seconds: 15)) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    expect(controller.isLoading, isFalse, reason: '回复后 AI 流应跑完');
    expect(controller.isWaitingUserPrompt, isFalse);
    // 问题在最终气泡中仍然可见（未被覆盖）。
    expect(controller.messages.last.text, contains('你喜欢苹果还是香蕉？'));
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

/// 脚本化 AI 后端（ask_user 回归专用）：
/// - 非流式 callNonStreaming 首次请求返回「前置正文 + ask_user 工具调用」。
///   前置正文会触发打字机定时器（旧 bug 的覆盖源），tool_calls 驱动 _onAskUser。
/// - 用户回复后的第二轮 callNonStreaming 返回纯文本收尾，使流程正常结束。
/// - 流式兜底（正常不会走到）：返回一段收尾文本。
class _FakeAskUserAdapter implements HttpClientAdapter {
  int _nonStreamCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.responseType == ResponseType.stream) {
      final sse = 'data: ${jsonEncode({
        'choices': [
          {
            'delta': {'content': '好的，已记录你的选择。'}
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

    _nonStreamCalls++;
    final body = _nonStreamCalls == 1
        ? {
            'choices': [
              {
                'message': {
                  'content': '让我确认一下你的偏好。',
                  'tool_calls': [
                    {
                      'id': 'call_1',
                      'type': 'function',
                      'function': {
                        'name': 'ask_user',
                        'arguments':
                            jsonEncode({'prompt': '你喜欢苹果还是香蕉？'}),
                      }
                    }
                  ]
                }
              }
            ]
          }
        : {
            'choices': [
              {
                'message': {'content': '好的，已记录你的选择。'}
              }
            ]
          };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {'content-type': ['application/json']},
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
