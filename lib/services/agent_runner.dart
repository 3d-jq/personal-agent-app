import 'dart:async';

import '../core/prompt_builder.dart';
import '../models/agent.dart';
import '../models/chat_message.dart';
import '../tools/tool_registry.dart';
import '../widgets/ai_settings_sheet.dart' show VendorConfig;
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

  /// 每次 run() 都重建 system prompt，不缓存，确保 Agent 身份隔离
  /// 结构：固定前缀（身份+规则+团队）→ 动态后缀（角色人设+记忆），利于 prompt caching
  Future<String> _buildSystemPrompt(
    Agent agent, {
    required List<String> memberNames,
    required Map<String, String> memberRoles,
    String groupName = '',
    String groupDesc = '',
    required DateTime now,
  }) async {
    final buf = StringBuffer();

    // ═══ 固定前缀（不变部分，利于缓存） ═══

    // 身份声明（最开头，最强语气）
    buf.writeln('<role>');
    buf.writeln('你是「${agent.name}」。');
    buf.writeln('【核心身份约束】你只能以「${agent.name}」的身份发言，绝对禁止：');
    buf.writeln('- 冒充其他成员（如产品经理、开发者、美食推荐官等）');
    buf.writeln('- 以其他成员的口吻或风格说话');
    buf.writeln('- 声称自己是其他角色');
    buf.writeln('- 在回复中使用其他成员的身份描述');
    buf.writeln('你的身份是唯一的：「${agent.name}」，角色定位：${agent.role}');
    if (groupName.isNotEmpty) {
      buf.writeln('你正在「$groupName」项目群中协作。');
      if (groupDesc.isNotEmpty) buf.writeln('项目描述：$groupDesc');
    } else {
      buf.writeln('你正在一个多 Agent 项目群里与其他成员协作讨论。');
    }
    buf.writeln('群内共 ${memberNames.length} 位成员：${memberNames.join("、")}');
    buf.writeln('</role>');
    buf.writeln();

    // 发言规则
    buf.writeln('<rules>');
    buf.writeln('你是「${agent.name}」，你的角色定位是：${agent.role}。');
    buf.writeln('【身份锁定】你必须始终以「${agent.name}」的身份发言，不要模仿或冒充其他任何成员。');
    buf.writeln('如果被问到其他成员的职责，你只能说"这是${agent.name}的职责范围之外，请咨询对应成员"。');
    if (agent.isCoordinator) {
      buf.writeln('你是团队的常驻协调者。用户发送任何消息你都可以主动回复。');
      buf.writeln('你的职责：理解用户意图、分析任务需求，直接回复用户或给出建议。');
      buf.writeln('你可以 @ 其他成员来讨论或征求意见。');
    } else {
      buf.writeln('你可以回复被 @ 提及的消息，也可以在合适的时候主动发言。');
      buf.writeln('如果你认为其他成员更适合回答，可以用 @名字 来邀请他们参与讨论。');
    }
    buf.writeln('用户是群主，拥有最终决策权。重要决策必须由群主确认。');
    buf.writeln(
      '【协作模式】你可以通过 @名字 来邀请其他成员参与讨论。例如：@产品经理 你觉得这个需求合理吗？',
    );
    buf.writeln(
      '【禁止幻觉】回答时事、数据、地点、人物、版本等你不能 100% 确定的事实时，必须调用 searxng_search 或 tavily_search 确认，禁止凭训练数据猜测；tavily_search 效果通常更好，当 searxng_search 结果不理想时请换用 tavily_search。',
    );
    buf.writeln(
      '【低频工具发现】对于不常用、场景化或你不确定名称的工具（如 AI日报、企业 MCP 等），先使用 tool_search 搜索，确认名称和参数后，再用 defer_execute_tool 调用。',
    );
    buf.writeln('【先工具后回答】工具返回前不要给出最终结论，只能基于工具返回的内容回答。');
    buf.writeln('</rules>');
    buf.writeln();

    // ═══ 实时上下文 ═══
    buf.writeln('<context>');
    buf.writeln('当前时间：${PromptBuilder.currentTimeContext(now)}');
    buf.writeln('</context>');
    buf.writeln();

    // 团队成员能力（排除自己）
    final others = memberNames.where((n) => n != agent.name).toList();
    if (others.isNotEmpty) {
      buf.writeln('<team>');
      for (final name in others) {
        final role = memberRoles[name] ?? '';
        buf.writeln('- @$name${role.isNotEmpty ? "：$role" : ""}');
      }
      if (agent.isCoordinator) {
        buf.writeln('你了解每位成员的能力。你可以 @ 他们来讨论或征求意见。');
      } else {
        buf.writeln('你可以 @ 其他成员来讨论或征求意见。完成后可以用 @名字 来通知相关成员。');
      }
      buf.writeln('</team>');
      buf.writeln();
    }

    // 对话历史格式说明
    buf.writeln('<history_format>');
    buf.writeln('对话历史中每条消息带 name 字段：');
    buf.writeln('- name="${agent.name}" → 这是你（${agent.name}）发出的消息');
    buf.writeln('- name="群主" → 这是用户说的话');
    buf.writeln('- name="其他名字" → 那是其他 Agent 说的话，不是你说的');
    buf.writeln();
    buf.writeln('【关键规则】');
    buf.writeln('1. name="${agent.name}" 的消息才是你写的，其他 name 的消息都是别人写的');
    buf.writeln('2. 你只能以「${agent.name}」的身份回复，不要模仿其他 name 的风格');
    buf.writeln('3. 如果用户问你关于其他 name 的职责，你只能说"请咨询${agent.name}"');
    buf.writeln('</history_format>');
    buf.writeln();

    // ═══ 动态后缀（变化部分） ═══

    // Agent 角色人设
    if (agent.systemPrompt.isNotEmpty) {
      buf.writeln('<persona>');
      buf.writeln(agent.systemPrompt);
      buf.writeln('</persona>');
      buf.writeln();
    }

    return buf.toString();
  }

  /// 消息序列化：所有消息都标注 name 字段
  /// 构建 Agent 的独立对话历史视图
  ///
  /// 原则：每个 Agent 只看到自己和用户的消息作为"对话"，
  /// 其他 Agent 的消息作为"上下文"（system 角色），避免身份混淆。
  List<Map<String, dynamic>> _buildHistory(
    List<_GroupMsg> msgs,
    String systemPrompt,
    String selfLabel,
  ) {
    const maxMsgs = 50;
    final window = msgs.length > maxMsgs
        ? msgs.sublist(msgs.length - maxMsgs)
        : msgs;

    final history = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];
    for (final m in window) {
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
    return history;
  }

  final Map<String, ToolRegistry> _scopedCache = {};

  ToolRegistry _scopedRegistry(Agent agent) {
    final key = agent.allowedToolNames.join(',');
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
        scoped.register(tool);
      }

      // 如果 Agent 允许 tool_search / defer_execute_tool，
      // 把 discoverable 工具也注入，让 AI 能按需发现。
      for (final tool in baseRegistry.discoverable) {
        if (!canDiscover && !allowed.contains(tool.name)) continue;
        if (!agent.isCoordinator && !tool.readOnly) continue;
        scoped.registerDiscoverable(tool);
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
  }) async* {
    try {
      final systemPrompt = await _buildSystemPrompt(
        agent,
        memberNames: memberNames,
        memberRoles: memberRoles,
        groupName: groupName,
        groupDesc: groupDesc,
        now: DateTime.now(),
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

      final messages = _buildHistory(mapped, systemPrompt, agent.name);
      final ai = AIService(
        baseUrl: vendor.baseUrl,
        apiKey: vendor.apiKey,
        providerName: vendor.name,
        model: agent.model.isNotEmpty ? agent.model : vendor.model,
        thinkingEffort: thinkingEffort,
        toolRegistry: _scopedRegistry(agent),
      );
      yield* ai.sendMessageStream(messages);
    } catch (e) {
      yield ErrorEvent('[系统错误: $e]');
    }
  }
}
