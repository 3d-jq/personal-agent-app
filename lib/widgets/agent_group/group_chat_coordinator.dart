import 'dart:async';

import '../../models/agent.dart';
import '../../models/agent_group.dart';
import '../../models/chat_message.dart';
import '../../widgets/ai_settings_sheet.dart';

/// Agent 状态枚举
enum AgentStatus {
  idle,
  thinking,
  replied,
  error, // 执行出错（工具/流异常）
  timeout, // 连接或响应超时（长时间无响应）
  cancelled, // 被主 Agent（terminate_subagent）或用户（停止）终止
}

/// 协作引擎：处理 Agent 调度逻辑
class GroupChatCoordinator {
  final AISettings aiSettings;
  final List<Agent> members;

  GroupChatCoordinator({
    required this.aiSettings,
    required this.members,
  });

  /// 自动调度：群聊「主从模式」下，协调者（主 Agent）永远是第一棒。
  ///
  /// 协调者负责理解用户意图、把专业任务分派给对应子 Agent、并在子 Agent
  /// 回答后做汇总（汇总轮由 [GroupChatController._handleRelay] 自动触发）。
  /// 因此这里不需要 LLM 选人——只要群里有协调者就直接选它，
  /// 专业问题由协调者在其回复里 @ 子 Agent 来完成，避免「抢答 + 重复」。
  Future<String?> autoPickSpeaker({
    required AgentGroup? group,
    required List<ChatMessage> messages,
    required Map<String, String> speakerNames,
  }) {
    final coordinator = members.where((a) => a.isCoordinator).firstOrNull;
    if (coordinator != null) return Future.value(coordinator.name);
    // 极少见：群里没有标记协调者时，退回群内第一个成员。
    final first = members.firstOrNull;
    return Future.value(first?.name);
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
