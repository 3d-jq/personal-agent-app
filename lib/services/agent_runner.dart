import 'dart:async';

import '../models/agent.dart';
import '../models/chat_message.dart';
import '../widgets/ai_settings_sheet.dart' show VendorConfig;
import 'ai_service.dart';
import 'memory_storage.dart';
import '../tools/tool_registry.dart';

/// 群聊消息的最小视图（避免把 ChatMessage 直接喂给 AI，引入与原 chat_screen 不同的序列化）
class _GroupMsg {
  final String speakerLabel; // "你" / "产品经理" 等
  final String text;
  final bool isUser;
  _GroupMsg(this.speakerLabel, this.text, this.isUser);
}

/// 单个 Agent 被 @ 后的"回复一次"执行器。
/// - 根据 Agent.allowedToolNames 构造受限 ToolRegistry
/// - 根据 Agent.vendorId / model 选定 AI 后端
/// - 复用 MemoryStorage 加载用户全局记忆（方案 B：用户记忆共享，Agent 私有笔记隔离）
/// - **方案 A 严格隔离**：会修改用户状态的工具（写操作）永久从 Agent 工具集合里剔除，
///   即使用户在 Agent 配置里勾选了也不会注入给 AI。
class AgentRunner {
  final ToolRegistry baseRegistry;
  AgentRunner({required this.baseRegistry});

  /// 会污染用户数据的"写操作"工具黑名单（方案 A 严格隔离）
  /// 这些工具 Agent 永远调不到，与 Agent.allowedToolNames 求交集后再过滤一次。
  static const Set<String> writeStateTools = {
    'save_memory',
    'save_note',
    'reminder',
    'calendar',
    'file_manager',
    'clipboard',
  };

  /// 拼装 Agent 视角的 system prompt：基础 + Agent 自身人设 + 用户记忆（共享）+ 群上下文说明
  Future<String> _buildSystemPrompt(Agent agent, {
    required List<String> memberNames,
    required Map<String, String> memberRoles,
    String groupName = '',
    String groupDesc = '',
  }) async {
    final buf = StringBuffer();
    // 群组上下文
    if (groupName.isNotEmpty) {
      buf.writeln('你正在「$groupName」项目群中协作。');
      if (groupDesc.isNotEmpty) buf.writeln('项目描述：$groupDesc');
      buf.writeln('群内共 ${memberNames.length} 位成员（含你）。');
      buf.writeln();
    } else {
      buf.writeln('你正在一个多 Agent 项目群里与其他成员协作讨论。');
    }

    buf.writeln('你的名字是「${agent.name}」。');
    if (agent.name == 'DWeis') {
      buf.writeln('你是团队的常驻协调者。用户发送任何消息你都可以主动回复，不需要被 @。');
      buf.writeln('你的职责是理解用户意图、拆解任务、按需求 @ 其他 Agent 来分工协作。');
    } else {
      buf.writeln('重要规则：你只能回复被 @ 提及的消息。如果消息中没有 @${agent.name}，请保持沉默，不要主动发言。');
    }
    buf.writeln('群内所有消息对你可见。');
    buf.writeln('回复时无需重复 @ 自己，直接给出观点即可。');

    // 权限：群主是用户
    buf.writeln('用户是这个群的群主，拥有最终决策权。你的角色是提供专业建议和分析，');
    buf.writeln('但所有重要决策（如方案确定、方向调整、最终交付）必须由群主确认。');
    buf.writeln('当你完成分析后，请明确告知群主你的建议和理由，等待群主拍板。');
    buf.writeln();

    // 协作指令：告知每个同伴的能力，按需精准分派
    final others = memberNames.where((n) => n != agent.name).toList();
    if (others.isNotEmpty) {
      buf.writeln('## 团队其他成员及其能力');
      for (final name in others) {
        final role = memberRoles[name] ?? '';
        buf.writeln('- @$name${role.isNotEmpty ? "：$role" : ""}');
      }
      buf.writeln();

      if (agent.name == 'DWeis') {
        // DWeis 是协调者，可以 @ 所有人
        buf.writeln('作为团队协调者，你可以通过 @名字 将任务分派给任何成员。');
        buf.writeln('但请注意：只 @ 真正需要参与的成员，不要无脑 @ 所有人。');
        buf.writeln('转交任务时说明需要对方做什么，不要只 @ 名字。');
      } else {
        // 普通 Agent：只能 @ DWeis，不能直接 @ 其他 Agent
        final canAtDweis = others.contains('DWeis');
        if (canAtDweis) {
          buf.writeln('通信规则：你只能 @DWeis 来转交任务或汇报结果，不要直接 @ 其他 Agent。');
          buf.writeln('所有跨 Agent 协调由 DWeis 统一处理。');
        }
        buf.writeln('如果任务很简单、不需要他人参与，你自己直接完成即可，无需 @ 任何人。');
      }
    }
    buf.writeln();

    if (agent.systemPrompt.isNotEmpty) {
      buf.writeln('## 你的角色与风格');
      buf.writeln(agent.systemPrompt);
      buf.writeln();
    }

    // 用户全局记忆：共享（方案 B）
    final mem = MemoryStorage();
    await mem.loadAll();
    final pref = mem.preferencePrompt;
    final facts = mem.memoryContext;
    if (pref.isNotEmpty) {
      buf.writeln('## 用户偏好（共享）');
      buf.writeln(pref);
      buf.writeln();
    }
    if (facts.isNotEmpty) {
      buf.writeln('## 用户相关事实（共享）');
      buf.writeln(facts);
      buf.writeln();
    }
    return buf.toString();
  }

  /// 将群消息序列化为 OpenAI 格式
  /// 关键：只有当前 Agent 自己的历史发言用 assistant role，
  /// 用户发言和其他 Agent 的发言都用 user role，避免身份混淆。
  List<Map<String, dynamic>> _buildHistory(
    List<_GroupMsg> msgs,
    String systemPrompt,
    String selfLabel,
  ) {
    final history = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt}
    ];
    for (final m in msgs) {
      final isSelf = !m.isUser && m.speakerLabel == selfLabel;
      history.add({
        'role': isSelf ? 'assistant' : 'user',
        'content': m.isUser ? m.text : '【${m.speakerLabel}】${m.text}',
      });
    }
    return history;
  }

  /// 构造一个仅含 Agent 白名单工具的 ToolRegistry
  /// 双重过滤：① Agent.allowedToolNames 白名单 ② writeStateTools 黑名单（方案 A）
  final Map<String, ToolRegistry> _scopedCache = {};

  ToolRegistry _scopedRegistry(Agent agent) {
    final key = agent.allowedToolNames.join(',');
    return _scopedCache.putIfAbsent(key, () {
      final scoped = ToolRegistry();
      final allowed = agent.allowedToolNames.toSet();
      for (final tool in baseRegistry.all) {
        if (!allowed.contains(tool.name)) continue;
        if (writeStateTools.contains(tool.name)) continue;
        scoped.register(tool);
      }
      return scoped;
    });
  }

  /// 执行一次：把群聊历史喂给 Agent，让它回复。
  /// 返回 Stream<String>，调用方负责拼到 ChatMessage.text 上。
  Stream<String> run({
    required Agent agent,
    required VendorConfig vendor,
    required List<ChatMessage> groupMessages,
    List<String> memberNames = const [],
    Map<String, String> speakerNames = const {},  // speakerId → 名字
    Map<String, String> memberRoles = const {},    // name → 职能描述
    String groupName = '',
    String groupDesc = '',
  }) async* {
    try {
      final systemPrompt = await _buildSystemPrompt(agent,
          memberNames: memberNames,
          memberRoles: memberRoles,
          groupName: groupName,
          groupDesc: groupDesc);
    // 把群消息映射为 _GroupMsg，通过 speakerNames 查到真实名字
    final mapped = <_GroupMsg>[];
    for (final m in groupMessages) {
      if (m.isStreaming) continue;
      String label;
      if (m.isUser) {
        label = '你';
      } else {
        // speakerId 命中 speakerNames → 用真实名字；命中自己 → 用 agent.name；否则回退
        final sid = m.speakerId ?? '';
        if (sid == agent.id) {
          label = agent.name;
        } else {
          label = speakerNames[sid] ?? '其他成员';
        }
      }
      // 用户消息用原文，Agent 消息用 cleanText（去除 🔧✅❌ 工具状态标记）
      final content = m.isUser ? m.text : m.cleanText;
      mapped.add(_GroupMsg(label, content, m.isUser));
    }
    final messages = _buildHistory(mapped, systemPrompt, agent.name);
    final ai = AIService(
      baseUrl: vendor.baseUrl,
      apiKey: vendor.apiKey,
      providerName: vendor.name,
      model: agent.model.isNotEmpty ? agent.model : vendor.model,
      toolRegistry: _scopedRegistry(agent),
    );
    yield* ai.sendMessageStream(messages);
    } catch (e) {
      yield '\n\n[系统错误: $e]';
    }
  }
}
