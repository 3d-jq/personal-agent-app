import 'dart:async';

import '../models/agent.dart';
import '../models/chat_message.dart';
import '../widgets/ai_settings_sheet.dart' show VendorConfig;
import 'ai_service.dart';
import 'memory_storage.dart';
import '../tools/tool_registry.dart';

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
  Future<String> _buildSystemPrompt(Agent agent, {
    required List<String> memberNames,
    required Map<String, String> memberRoles,
    String groupName = '',
    String groupDesc = '',
    String userMessage = '',
  }) async {
    final buf = StringBuffer();

    // ═══ 固定前缀（不变部分，利于缓存） ═══

    // 身份声明（最开头，最强语气）
    buf.writeln('<role>');
    buf.writeln('你是「${agent.name}」。你不是其他任何人。请始终以${agent.name}的身份发言。');
    if (groupName.isNotEmpty) {
      buf.writeln('你正在「$groupName」项目群中协作。');
      if (groupDesc.isNotEmpty) buf.writeln('项目描述：$groupDesc');
    } else {
      buf.writeln('你正在一个多 Agent 项目群里与其他成员协作讨论。');
    }
    buf.writeln('群内共 ${memberNames.length} 位成员。');
    buf.writeln('</role>');
    buf.writeln();

    // 发言规则
    buf.writeln('<rules>');
    if (agent.isCoordinator) {
      buf.writeln('你是团队的常驻协调者。用户发送任何消息你都可以主动回复。');
      buf.writeln('你的职责：理解用户意图、拆解任务、按需求 @ 其他 Agent 来分工协作。');
    } else {
      buf.writeln('你只能回复被 @ 提及的消息。如果消息中没有 @${agent.name}，不要发言。');
    }
    buf.writeln('用户是群主，拥有最终决策权。重要决策必须由群主确认。');
    buf.writeln('</rules>');
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
        buf.writeln('你可以通过 @名字 将任务分派给任何成员。只 @ 真正需要参与的成员。');
      } else {
        buf.writeln('完成自己的任务后，优先 @DWeis 汇报进度。');
      }
      buf.writeln('</team>');
      buf.writeln();
    }

    // 对话历史格式说明
    buf.writeln('<history_format>');
    buf.writeln('每条消息带 name 字段标注发言人：name="群主"=用户，name="你的名字"=你，name="其他Agent名字"=那个Agent。');
    buf.writeln('你可以引用同伴观点，如"我同意产品经理的分析"。请严格根据 name 字段区分发言人。');
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

    // 用户偏好 + 相关记忆（按需注入）
    final mem = MemoryStorage();
    await mem.loadAll();
    final prefs = mem.cachedPreferences;
    if (prefs.isNotEmpty) {
      buf.writeln('<preferences>');
      for (final p in prefs) {
        buf.writeln('- ${p.content}');
      }
      buf.writeln('</preferences>');
      buf.writeln();
    }

    final relevantFacts = mem.relevantFacts(userMessage);
    if (relevantFacts.isNotEmpty) {
      buf.writeln('<memory>');
      for (final f in relevantFacts) {
        buf.writeln('- ${f.content}');
      }
      buf.writeln('</memory>');
    }

    return buf.toString();
  }

  /// 消息序列化：所有消息都标注 name 字段
  /// 窗口截断：保留最近 50 条
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
      {'role': 'system', 'content': systemPrompt}
    ];
    for (final m in window) {
      final isSelf = !m.isUser && m.speakerLabel == selfLabel;
      if (m.isUser) {
        history.add({'role': 'user', 'content': m.text, 'name': '群主'});
      } else if (isSelf) {
        history.add({'role': 'assistant', 'content': m.text, 'name': m.speakerLabel});
      } else {
        history.add({'role': 'assistant', 'content': m.text, 'name': m.speakerLabel});
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
      for (final tool in baseRegistry.all) {
        if (!allowed.contains(tool.name)) continue;
        // Agent 群中非协调者 Agent 只能使用只读工具
        if (!agent.isCoordinator && !tool.readOnly) continue;
        scoped.register(tool);
      }
      return scoped;
    });
  }

  Stream<String> run({
    required Agent agent,
    required VendorConfig vendor,
    required List<ChatMessage> groupMessages,
    List<String> memberNames = const [],
    Map<String, String> speakerNames = const {},
    Map<String, String> memberRoles = const {},
    String groupName = '',
    String groupDesc = '',
  }) async* {
    try {
      // 提取最近的用户消息，用于记忆筛选
      String lastUserMsg = '';
      for (final m in groupMessages.reversed) {
        if (m.isUser && !m.isStreaming) {
          lastUserMsg = m.text;
          break;
        }
      }

      final systemPrompt = await _buildSystemPrompt(agent,
          memberNames: memberNames,
          memberRoles: memberRoles,
          groupName: groupName,
          groupDesc: groupDesc,
          userMessage: lastUserMsg);

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
        toolRegistry: _scopedRegistry(agent),
      );
      yield* ai.sendMessageStream(messages);
    } catch (e) {
      yield '\n\n[系统错误: $e]';
    }
  }
}
