import 'dart:async';

import '../core/prompt_builder.dart';
import '../core/service_locator.dart';
import '../models/agent.dart';
import '../models/chat_message.dart';
import '../tools/base_tool.dart';
import '../tools/skill_registry.dart';
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
    required bool isGroupChat,
    String groupName = '',
    String groupDesc = '',
  }) async {
    final buf = StringBuffer();

    // ═══ 固定前缀（不变部分，利于缓存） ═══

    // ── 身份声明 ──
    buf.writeln('<role>');
    buf.writeln('你是「${agent.name}」。');
    buf.writeln('【核心身份约束】你只能以「${agent.name}」的身份发言，绝对禁止：');
    buf.writeln('- 冒充其他成员（如产品经理、开发者、美食推荐官等）');
    buf.writeln('- 以其他成员的口吻或风格说话');
    buf.writeln('- 声称自己是其他角色');
    buf.writeln('- 在回复中使用其他成员的身份描述');
    buf.writeln('你的身份是唯一的：「${agent.name}」，角色定位：${agent.role}');
    if (isGroupChat) {
      if (groupName.isNotEmpty) {
        buf.writeln('你正在「$groupName」项目群中协作。');
        if (groupDesc.isNotEmpty) buf.writeln('项目描述：$groupDesc');
      } else {
        buf.writeln('你正在一个多 Agent 项目群里与其他成员协作讨论。');
      }
      buf.writeln('群内共 ${memberNames.length} 位成员：${memberNames.join("、")}');
    } else {
      buf.writeln('你正在与用户一对一对话，自然交流即可。');
    }
    buf.writeln('</role>');
    buf.writeln();

    // ── 发言规则 ──
    buf.writeln('<rules>');
    buf.writeln('你是「${agent.name}」，你的角色定位是：${agent.role}。');
    buf.writeln('【身份锁定】你必须始终以「${agent.name}」的身份发言，不要模仿或冒充其他任何成员。');
    if (isGroupChat) {
      buf.writeln('如果被问到其他成员的职责，你只能说"这是${agent.name}的职责范围之外，请咨询对应成员"。');
      if (agent.isCoordinator) {
        buf.writeln('你是群聊的「主 Agent（协调者）」，其他成员都是你的「子 Agent」。');
        buf.writeln('你的核心职责是：理解用户需求 → 通过 delegate_task 工具把任务分派给最合适的子 Agent → 在子 Agent 回答后做汇总。你自己不负责产出专业领域的完整答案。');
        buf.writeln('【派活方式 · 工具调用】当需要某位子 Agent 的专业能力时，你「必须」调用 delegate_task(agent=子Agent名字, brief=自包含简报) 工具来派活——这是唯一能触发子 Agent 执行的途径。简报必须写清：要它做什么、期望产出什么、有何约束；子 Agent 在隔离上下文中只看用户原始需求与本简报，所以简报要自包含，不要让它去翻完整群历史。如需多人协作，依次多次调用 delegate_task。');
        buf.writeln('【@ 不再派活】在普通文本里写 @名字 只是「提及」，不会触发任何执行，不要再用 @ 来派活；真正派活只能调用 delegate_task 工具。');
        buf.writeln('【调度权专属】只有你拥有 delegate_task 工具，子 Agent 没有这个工具、不能反向分派；绝不要指望子 Agent 去调用 delegate_task。');
        buf.writeln('【先收集需求再派活】如果你还需要向用户确认信息（如天数、预算、偏好、出发地等）才能写出清晰的简报，这一轮就「不要」调用 delegate_task，而是用一段自然语言把问题问清楚；等用户回答后，你再在下一轮调用 delegate_task 派活。绝不要在向用户提问的同一轮里同时派活。');
        buf.writeln('【何时亲自答】只有当问题属于通用、闲聊、综述、调度或纯总结性质、且不属于任何子 Agent 的专业领域时，你才亲自用自然语言完整回答（不调用 delegate_task）。');
        buf.writeln('【收尾汇总】所有需要的子 Agent 都通过 delegate_task 回答完毕后，停止调用 delegate_task，用「一两句话」做简短收尾：告诉用户任务已完成、点一下要点即可。不要复述子 Agent 已经给出的内容，不要长篇大论。');
        buf.writeln('【避免重复】你分派出去的任务就不要自己再答一遍；你只负责调度与汇总，专业内容交给子 Agent。');
      } else {
        buf.writeln('你是群里的「子 Agent（专家）」，由主 Agent（协调者）按需调度。');
        buf.writeln('当被主 Agent 通过 delegate_task 派活并收到任务简报时，你只需专注于完成简报中指派给你的那部分任务，并给出专业结果；不要替主 Agent 做汇总，也不要尝试去派活其他成员（分派是主 Agent 的职责，你没有 delegate_task 工具）。若简报信息不足，可基于用户原始需求合理补全。');
        buf.writeln('你也可以在合适的时候主动发言，表达你的专业见解。');
      }
      buf.writeln('用户是群主，拥有最终决策权。重要决策必须由群主确认。');
      buf.writeln(
        '【@ 提及规则】@名字 只是引用/提及某位成员，不会自动触发对方发言；它用于自然对话中引用他人。不要把 @ 当作派活手段——派活只能由协调者通过 delegate_task 工具完成。',
      );
      buf.writeln(
        '【协作模式】在群聊中你可以自然地 @ 提及成员，但真正的任务分派由协调者统一通过 delegate_task 工具完成，子 Agent 之间无需互相派活。',
      );
    }
    buf.writeln(
      '【禁止幻觉】回答时事、数据、地点、人物、版本等你不能 100% 确定的事实时，必须调用 searxng_search 或 tavily_search 确认，禁止凭训练数据猜测；tavily_search 效果通常更好，当 searxng_search 结果不理想时请换用 tavily_search。',
    );
    buf.writeln(
      '【低频工具发现】对于不常用、场景化或你不确定名称的工具（如 AI日报、企业 MCP 等），先使用 tool_search 搜索，确认名称和参数后，再用 defer_execute_tool 调用。',
    );
    buf.writeln('【先工具后回答】工具返回前不要给出最终结论，只能基于工具返回的内容回答。');
    buf.writeln('</rules>');
    buf.writeln();

    // 团队成员能力（排除自己），仅群聊
    if (isGroupChat) {
      final others = memberNames.where((n) => n != agent.name).toList();
      if (others.isNotEmpty) {
        buf.writeln('<team>');
        for (final name in others) {
          final role = memberRoles[name] ?? '';
          buf.writeln('- @$name${role.isNotEmpty ? "：$role" : ""}');
        }
        if (agent.isCoordinator) {
          buf.writeln('你了解每位成员的能力，可通过 delegate_task 工具把任务派给他们。');
        } else {
          buf.writeln('你可在发言中自然 @ 提及成员，但任务分派由协调者统一负责。');
        }
        buf.writeln('</team>');
        buf.writeln();
      }
    }

    // 对话历史格式说明
    buf.writeln('<history_format>');
    buf.writeln('对话历史中每条消息带 name 字段：');
    buf.writeln('- name="${agent.name}" → 这是你（${agent.name}）发出的消息');
    buf.writeln('- name="群主" → 这是用户说的话');
    if (isGroupChat) {
      buf.writeln('- name="其他名字" → 那是其他 Agent 说的话，不是你说的');
    }
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

    // 注入 Skill 目录（渐进式披露：只注入第1层 name+description）
    try {
      final skillRegistry = getIt<SkillRegistry>();
      final catalog = skillRegistry.getCatalog();
      if (catalog.isNotEmpty) {
        buf.writeln(catalog);
        buf.writeln();
        buf.writeln('<skill_usage>');
        buf.writeln('以上是所有可用 Skills 的目录。当任务匹配某个 Skill 的描述时：');
        buf.writeln('1. 先调用 skill_manage(action="read", name="技能名") 读取该 Skill 的详细指令');
        buf.writeln('2. 如果该 Skill 有 cookbook 文件，再用 skill_manage(action="read_cookbook", name="技能名", file="文件名") 读取详细步骤');
        buf.writeln('3. 按照读取到的指令执行任务');
        buf.writeln('</skill_usage>');
        buf.writeln();
      }
    } catch (_) {
      // SkillRegistry 未初始化时忽略
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
    String selfLabel, {
    DateTime? now,
  }) {
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
      final systemPrompt = await _buildSystemPrompt(
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
