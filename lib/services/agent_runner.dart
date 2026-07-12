import 'dart:async';

import '../core/prompt_builder.dart';
import '../models/agent.dart';
import '../models/chat_message.dart';
import '../tools/base_tool.dart';
import '../tools/tool_registry.dart';
import '../widgets/ai_settings_sheet.dart' show VendorConfig;
import 'agent_system_prompt.dart';
import 'ai_service.dart';
import 'chat_stream_event.dart';

/// 群聊消息的最小视图
class _GroupMsg {
  final String speakerLabel;
  final String text;
  final bool isUser;
  _GroupMsg(this.speakerLabel, this.text, this.isUser);
}

/// 单个 Agent 被 @ 后的"回复一次"执行器。
class AgentRunner {
  final ToolRegistry baseRegistry;
  AgentRunner({required this.baseRegistry});

  /// 消息序列化：所有消息都标注 name 字段
  /// 构建 Agent 的独立对话历史视图
  ///
  /// 原则：每个 Agent 只看到自己和用户的消息作为"对话"，
  /// 其他 Agent 的消息作为"上下文"（system 角色），避免身份混淆。
  List<Map<String, dynamic>> _buildHistory(
    List<_GroupMsg> msgs,
    String systemPrompt,
    String selfLabel, {
    DateTime? now,
  }) {
    final history = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];
    for (final m in msgs) {
      if (m.isUser) {
        // 用户消息：保持 user 角色
        history.add({'role': 'user', 'content': m.text, 'name': '群主'});
      } else if (m.speakerLabel == selfLabel) {
        // 自己的消息：保持 assistant 角色
        history.add({
          'role': 'assistant',
          'content': m.text,
          'name': m.speakerLabel,
        });
      } else {
        // 其他 Agent 的消息：转为 system 角色（作为上下文），不混淆身份
        history.add({
          'role': 'system',
          'content': '[${m.speakerLabel}的发言] ${m.text}',
        });
      }
    }
    // 当前时间不进 system，追加到历史末尾的一条 user 消息，
    // 保证 system 前缀恒定，两厂商 prompt cache 可稳定命中。
    if (now != null) {
      history.add({
        'role': 'user',
        'content': '当前时间：${PromptBuilder.currentTimeContext(now)}',
      });
    }
    return history;
  }

  final Map<String, ToolRegistry> _scopedCache = {};

  ToolRegistry _scopedRegistry(Agent agent, {List<AgentTool>? dispatchTools}) {
    // 缓存键加入 dispatchTools 是否存在：协调者（带专属工具集）与子 Agent
    // （不带）即使 allowedToolNames 相同也不会共用同一份 registry。
    final key = '${agent.allowedToolNames.join(',')}#${dispatchTools != null}';
    return _scopedCache.putIfAbsent(key, () {
      final scoped = ToolRegistry();
      final allowed = agent.allowedToolNames.toSet();
      final canDiscover =
          allowed.contains('tool_search') ||
          allowed.contains('defer_execute_tool');

      for (final tool in baseRegistry.all) {
        if (!allowed.contains(tool.name)) continue;
        // Agent 群中非协调者 Agent 只能使用只读工具
        if (!agent.isCoordinator && !tool.readOnly) continue;
        // 禁用 AskUserTool（群聊中没有 onAsk 回调，会卡死）
        if (tool.name == 'ask_user') continue;
        scoped.register(tool);
      }

      // 如果 Agent 允许 tool_search / defer_execute_tool，
      // 把 discoverable 工具也注入，让 AI 能按需发现。
      for (final tool in baseRegistry.discoverable) {
        if (!canDiscover && !allowed.contains(tool.name)) continue;
        if (!agent.isCoordinator && !tool.readOnly) continue;
        // 禁用 AskUserTool
        if (tool.name == 'ask_user') continue;
        scoped.registerDiscoverable(tool);
      }

      // 协调者专属工具集（派活 + 终止子 Agent 等）：由控制器注入，子 Agent 不注册（调度权独占）。
      if (dispatchTools != null) {
        for (final t in dispatchTools) {
          scoped.register(t);
        }
      }

      return scoped;
    });
  }

  Stream<ChatStreamEvent> run({
    required Agent agent,
    required VendorConfig vendor,
    required List<ChatMessage> groupMessages,
    List<String> memberNames = const [],
    Map<String, String> speakerNames = const {},
    Map<String, String> memberRoles = const {},
    String groupName = '',
    String groupDesc = '',
    String thinkingEffort = 'medium',
    List<AgentTool>? dispatchTools,
    bool isGroupChat = false,
  }) async* {
    try {
      final systemPrompt = buildAgentSystemPrompt(
        agent,
        memberNames: memberNames,
        memberRoles: memberRoles,
        isGroupChat: isGroupChat,
        groupName: groupName,
        groupDesc: groupDesc,
      );

      final mapped = <_GroupMsg>[];
      for (final m in groupMessages) {
        if (m.isStreaming) continue;
        String label;
        if (m.isUser) {
          label = '你';
        } else {
          final sid = m.speakerId ?? '';
          if (sid == agent.id) {
            label = agent.name;
          } else {
            label = speakerNames[sid] ?? '其他成员';
          }
        }
        final content = m.isUser ? m.text : m.cleanText;
        mapped.add(_GroupMsg(label, content, m.isUser));
      }

      final messages = _buildHistory(mapped, systemPrompt, agent.name, now: DateTime.now());
      final scopedRegistry = _scopedRegistry(agent, dispatchTools: dispatchTools);
      // 每个 Agent 每次执行前重置工具调用计数：配额归该 Agent 当轮独占，
      // 避免群里权限相同的子 Agent 共用同一缓存 registry、且群聊从不 resetCallCounts
      // 导致的「跨 Agent / 跨轮次累积撞 10 次上限」问题（见 v1.4.15）。
      scopedRegistry.resetCallCounts();
      final ai = AIService(
        baseUrl: vendor.baseUrl,
        apiKey: vendor.apiKey,
        model: agent.model.isNotEmpty ? agent.model : vendor.model,
        thinkingEffort: thinkingEffort,
        isAnthropic: vendor.isAnthropic,
        toolRegistry: scopedRegistry,
      );
      yield* ai.sendMessageStream(messages);
    } catch (e) {
      yield ErrorEvent('[系统错误: $e]');
    }
  }
}
