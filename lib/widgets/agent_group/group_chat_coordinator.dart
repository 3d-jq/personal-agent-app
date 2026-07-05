import 'dart:async';

import '../../models/agent.dart';
import '../../models/chat_message.dart';
import '../../services/ai_service.dart';
import '../../services/chat_stream_event.dart';
import '../../widgets/ai_settings_sheet.dart';
import 'agent_group_theme.dart';

/// Agent 状态枚举
enum AgentStatus {
  idle,
  thinking,
  replied,
}

/// 协作引擎：处理 Agent 调度逻辑
class GroupChatCoordinator {
  final AISettings aiSettings;
  final List<Agent> members;

  GroupChatCoordinator({
    required this.aiSettings,
    required this.members,
  });

  /// 自动调度：系统判断哪个 Agent 应该回复
  Future<String?> autoPickSpeaker({
    required AgentGroup? group,
    required List<ChatMessage> messages,
  }) {
    final coordinator = members.where((a) => a.isCoordinator).firstOrNull;
    if (coordinator != null) return Future.value(coordinator.name);

    final manager = members.firstOrNull;
    if (manager == null) return Future.value(null);

    return managerPickSpeaker(manager, [], messages: messages);
  }

  /// Manager 判断下一位发言的 Agent
  Future<String?> managerPickSpeaker(
    Agent manager,
    List<String> alreadySpoken, {
    required List<ChatMessage> messages,
  }) async {
    final vendor = aiSettings.selectedVendor ??
        (aiSettings.vendors.isNotEmpty ? aiSettings.vendors.first : null);
    if (vendor == null || vendor.apiKey.isEmpty) return null;

    final candidates = members
        .where((a) => a.id != manager.id && !alreadySpoken.contains(a.name))
        .toList();
    if (candidates.isEmpty) return 'STOP';

    final roleList = candidates
        .map((a) => '- ${a.name}：${a.role.isNotEmpty ? a.role : '通用助手'}')
        .join('\n');

    final prompt = '''你是「${manager.name}」，群的协调者。
根据用户的消息和已有对话，判断哪位成员最适合回复。
只能从下面列表中选择一人，或回复 STOP 表示不需要更多回复。

【可选成员】
$roleList

【已有回复的成员】
${alreadySpoken.isEmpty ? '(暂无)' : alreadySpoken.join('、')}

【用户的消息 + 对话】
${messages.map((m) => '${m.isUser ? "群主" : m.speakerId ?? '?'}: ${m.text}').join('\n')}

请只回复一个名字或 STOP：''';

    try {
      final ai = AIService(
        baseUrl: vendor.baseUrl,
        apiKey: vendor.apiKey,
        providerName: vendor.name,
        model: vendor.model,
        maxTokens: 50,
      );
      final buf = StringBuffer();
      await for (final event in ai.sendMessageStream([
        {'role': 'user', 'content': prompt},
      ])) {
        if (event is TextChunkEvent) buf.write(event.text);
      }
      final choice = buf.toString().trim();
      for (final c in candidates) {
        if (choice == c.name ||
            choice.contains(RegExp('\\b${RegExp.escape(c.name)}\\b'))) {
          return c.name;
        }
      }
      if (choice.toUpperCase().contains('STOP')) return 'STOP';
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 解析 Agent 的 AI 后端配置
  VendorConfig? resolveVendor(Agent agent) {
    if (agent.vendorId.isNotEmpty) {
      final v = aiSettings.vendors.where((v) => v.id == agent.vendorId).firstOrNull;
      if (v != null) return v;
    }
    return aiSettings.selectedVendor ??
        (aiSettings.vendors.isNotEmpty ? aiSettings.vendors.first : null);
  }
}
