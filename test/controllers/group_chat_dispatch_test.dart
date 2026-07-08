import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/models/agent.dart';
import 'package:personal_agent_app/models/agent_group.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/services/agent_group_storage.dart';
import 'package:personal_agent_app/services/agent_storage.dart';
import 'package:personal_agent_app/services/ai_service_base.dart';
import 'package:personal_agent_app/services/connectivity_service.dart';
import 'package:personal_agent_app/widgets/agent_group/group_chat_controller.dart';
import 'package:personal_agent_app/widgets/ai_settings.dart';
import 'package:personal_agent_app/widgets/vendor_config.dart';

// 测试用的群组：1 个协调者 + 1 个子 Agent。
// 验证「工具调用派活」路径：协调者通过 delegate_task 工具把任务交给子 Agent，
// 子 Agent 在隔离上下文里回答；协调者本轮的自然语言收尾会被移到「所有子 Agent
// 回答之后」的末尾气泡，保证「派发 → 子 Agent 答 → 主 Agent 简短收尾」的顺序。
final _coordinator = Agent(
  id: 'coord',
  name: 'DWeis',
  role: '协调者',
  isCoordinator: true,
);
final _child = Agent(
  id: 'child',
  name: '子Bot',
  role: '测试助手',
);
final _group = AgentGroup(
  id: 'g1',
  name: '测试群',
  agentIds: ['coord', 'child'],
  messages: const [],
);

void main() {
  late HttpClientAdapter originalAdapter;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await resetDependencies();
    configureDependencies();
    getIt.unregister<AISettings>();
    getIt.registerSingleton<AISettings>(_FakeAISettings());
    getIt.unregister<AgentGroupStorage>();
    getIt.registerSingleton<AgentGroupStorage>(_FakeGroupStorage());
    getIt.unregister<AgentStorage>();
    getIt.registerSingleton<AgentStorage>(_FakeAgentStorage());
    getIt.unregister<ConnectivityService>();
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivity());
    // 拦截真实的 AI 网络请求，用脚本化响应驱动派活流程。
    originalAdapter = AiHttpClient.sharedDio.httpClientAdapter;
    AiHttpClient.sharedDio.httpClientAdapter = _FakeChatAdapter();
  });

  tearDown(() async {
    AiHttpClient.sharedDio.httpClientAdapter = originalAdapter;
    await resetDependencies();
  });

  test('协调者派活 → 子 Agent 答 → 末尾简短收尾（总结在最后）', () async {
    final controller = GroupChatController(groupId: 'g1');
    await controller.load();
    expect(controller.members.length, 2);

    await controller.send('请帮我写一首关于春天的诗');

    // 用户消息 + 协调者派发占位 + 子 Agent 回答 + 协调者末尾收尾
    expect(controller.messages.where((m) => m.isUser), hasLength(1));

    final childMsg = controller.messages.firstWhere(
      (m) => m.speakerId == 'child',
      orElse: () => ChatMessage(text: '', isUser: false),
    );
    expect(childMsg.text, contains('子Bot的回答'));

    // 协调者本轮有两条消息：派发占位（正文已移走、只留派发时间线）+ 末尾收尾总结
    final coordMsgs =
        controller.messages.where((m) => m.speakerId == 'coord').toList();
    expect(coordMsgs, hasLength(2));
    // 派发占位气泡：正文已移走，只剩派发时间线（步骤非空）
    expect(coordMsgs.first.text, isEmpty);
    expect(coordMsgs.first.steps, isNotEmpty);
    // 末尾收尾总结：是消息列表的最后一条，且在子 Agent 回答之后
    final summaryMsg = coordMsgs.last;
    expect(summaryMsg.text, contains('汇总'));
    expect(identical(controller.messages.last, summaryMsg), isTrue);
    final childIdx = controller.messages.indexOf(childMsg);
    final summaryIdx = controller.messages.indexOf(summaryMsg);
    expect(summaryIdx, greaterThan(childIdx));

    // 协调者与子 Agent 都参与了本轮
    expect(controller.participatedAgents, containsAll(['coord', 'child']));
    expect(controller.busy, isFalse);
  });
}

/// 脚本化 AI 后端：按调用顺序返回
/// 0) 协调者调用 delegate_task
/// 1) 子 Agent 的回答
/// 2) 协调者的末尾收尾总结
/// 其余返回空，防止意外循环。
class _FakeChatAdapter implements HttpClientAdapter {
  int _call = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final i = _call++;
    final isStream = options.responseType == ResponseType.stream;

    if (i == 0) {
      final body = jsonEncode({
        'choices': [
          {
            'message': {
              'content': '',
              'tool_calls': [
                {
                  'id': 'call_1',
                  'type': 'function',
                  'function': {
                    'name': 'delegate_task',
                    'arguments': jsonEncode({
                      'agent': '子Bot',
                      'brief': '请写一首关于春天的诗',
                    }),
                  },
                }
              ],
            }
          }
        ]
      });
      return ResponseBody.fromString(
        body,
        200,
        headers: {'content-type': ['application/json']},
      );
    }

    if (i == 1) {
      if (isStream) {
        final sse = 'data: ${jsonEncode({
          'choices': [
            {'delta': {'content': '子Bot的回答：春眠不觉晓'}}
          ]
        })}\n\ndata: [DONE]\n';
        return ResponseBody.fromString(
          sse,
          200,
          headers: {'content-type': ['text/event-stream']},
        );
      }
      final body = jsonEncode({
        'choices': [
          {
            'message': {'content': '子Bot的回答：春眠不觉晓'}
          }
        ]
      });
      return ResponseBody.fromString(
        body,
        200,
        headers: {'content-type': ['application/json']},
      );
    }

    // i >= 2：协调者收尾汇总
    final summary = '汇总：子Bot说 子Bot的回答：春眠不觉晓';
    if (isStream) {
      final sse = 'data: ${jsonEncode({
        'choices': [
          {'delta': {'content': summary}}
        ]
      })}\n\ndata: [DONE]\n';
      return ResponseBody.fromString(
        sse,
        200,
        headers: {'content-type': ['text/event-stream']},
      );
    }
    final body = jsonEncode({
      'choices': [
        {'message': {'content': summary}}
      ]
    });
    return ResponseBody.fromString(
      body,
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

class _FakeGroupStorage implements AgentGroupStorage {
  @override
  Future<List<AgentGroup>> loadAll() async => [_group];

  @override
  Future<void> save(AgentGroup g) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  AgentGroup? byId(String id) => id == _group.id ? _group : null;

  @override
  void clearCache() {}
}

class _FakeAgentStorage implements AgentStorage {
  @override
  Future<List<Agent>> loadAll() async => [_coordinator, _child];

  @override
  Future<Agent> add(Agent a) async => a;

  @override
  Future<void> update(Agent a) async {}

  @override
  Future<void> remove(String id) async {}

  @override
  Agent? byId(String id) =>
      [_coordinator, _child].where((a) => a.id == id).firstOrNull;

  @override
  Agent? byName(String name) =>
      [_coordinator, _child].where((a) => a.name == name).firstOrNull;

  @override
  void clearCache() {}
}

class _FakeConnectivity extends ConnectivityService {
  @override
  Future<bool> check() async => true;
}
