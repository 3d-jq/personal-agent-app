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

  static const Set<String> writeStateTools = {
    'save_memory', 'save_note', 'reminder', 'calendar', 'file_manager', 'clipboard',
  };

  /// 每次 run() 都重建 system prompt，不缓存，确保 Agent 身份隔离
  Future<String> _buildSystemPrompt(Agent agent, {
    required List<String> memberNames,
    required Map<String, String> memberRoles,
    String groupName = '',
    String groupDesc = '',
  }) async {
    final buf = StringBuffer();

    // ═══ 身份声明（最开头，最强语气） ═══
    buf.writeln('【身份确认】你是「${agent.name}」。你不是其他任何人。请始终以${agent.name}的身份发言。');
    buf.writeln();

    // 群组上下文
    if (groupName.isNotEmpty) {
      buf.writeln('你正在「$groupName」项目群中协作。');
      if (groupDesc.isNotEmpty) buf.writeln('项目描述：$groupDesc');
    } else {
      buf.writeln('你正在一个多 Agent 项目群里与其他成员协作讨论。');
    }
    buf.writeln('群内共 ${memberNames.length} 位成员。');
    buf.writeln();

    // 发言规则
    if (agent.isCoordinator) {
      buf.writeln('你是团队的常驻协调者。用户发送任何消息你都可以主动回复。');
      buf.writeln('你的职责：理解用户意图、拆解任务、按需求 @ 其他 Agent 来分工协作。');
    } else {
      buf.writeln('【发言规则】你只能回复被 @ 提及的消息。如果消息中没有 @${agent.name}，不要发言。');
    }
    buf.writeln();

    // 团队成员能力（排除自己）
    final others = memberNames.where((n) => n != agent.name).toList();
    if (others.isNotEmpty) {
      buf.writeln('## 团队其他成员及其能力');
      for (final name in others) {
        final role = memberRoles[name] ?? '';
        buf.writeln('- @$name${role.isNotEmpty ? "：$role" : ""}');
      }
      buf.writeln();

      if (agent.isCoordinator) {
        buf.writeln('作为协调者，你可以通过 @名字 将任务分派给任何成员。只 @ 真正需要参与的成员。');
      } else {
        buf.writeln('完成自己的任务后，优先 @DWeis 汇报进度。如果协调者已指定下一个负责人，也可直接 @该负责人。');
      }
      buf.writeln();
    }

    // 权限
    buf.writeln('用户是群主，拥有最终决策权。你的角色是提供专业建议，重要决策必须由群主确认。');
    buf.writeln();

    // 历史消息格式
    buf.writeln('## 对话历史格式');
    buf.writeln('每条消息带 name 字段标注发言人：name="群主"=用户发言，name="你的名字"=你自己的发言，name="其他Agent名字"=那个Agent的发言。');
    buf.writeln('你可以引用同伴观点，如"我同意产品经理的分析"。请严格根据 name 字段区分发言人。');
    buf.writeln();

    // Agent 角色人设
    if (agent.systemPrompt.isNotEmpty) {
      buf.writeln('## 你的角色与风格');
      buf.writeln(agent.systemPrompt);
      buf.writeln();
    }

    // 用户记忆
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
        if (writeStateTools.contains(tool.name)) continue;
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
      final systemPrompt = await _buildSystemPrompt(agent,
          memberNames: memberNames,
          memberRoles: memberRoles,
          groupName: groupName,
          groupDesc: groupDesc);

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
