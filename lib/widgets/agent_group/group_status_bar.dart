import 'package:flutter/material.dart';
import '../../core/agent_colors.dart';
import '../../models/agent.dart';
import 'group_chat_coordinator.dart';

/// Agent 状态栏组件
class GroupStatusBar extends StatelessWidget {
  final List<Agent> members;
  final Map<String, AgentStatus> agentStatus;
  final int discussionRound;
  final Set<String> participatedAgents;

  const GroupStatusBar({
    super.key,
    required this.members,
    required this.agentStatus,
    required this.discussionRound,
    required this.participatedAgents,
  });

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: nc.surface,
        border: Border(bottom: BorderSide(color: nc.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          if (discussionRound > 0) ...[
            _buildRoundBadge(nc),
            const SizedBox(width: 8),
          ],
          if (participatedAgents.isNotEmpty) ...[
            Icon(Icons.group, size: 14, color: nc.textSecondary),
            const SizedBox(width: 4),
            Text(
              '${participatedAgents.length} 人参与',
              style: TextStyle(fontSize: 12, color: nc.textSecondary),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: _buildAgentIndicators(nc)),
        ],
      ),
    );
  }

  Widget _buildRoundBadge(AgentColors nc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: nc.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '第 $discussionRound 轮',
        style: TextStyle(
          fontSize: 12,
          color: nc.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAgentIndicators(AgentColors nc) {
    return SizedBox(
      height: 24,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: members.map((m) {
          final status = agentStatus[m.id] ?? AgentStatus.idle;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _AgentIndicator(agent: m, status: status, nc: nc),
          );
        }).toList(),
      ),
    );
  }
}

/// 单个 Agent 状态指示器
class _AgentIndicator extends StatelessWidget {
  final Agent agent;
  final AgentStatus status;
  final AgentColors nc;

  const _AgentIndicator({
    required this.agent,
    required this.status,
    required this.nc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor, width: 0.5),
      ),
      child: status == AgentStatus.thinking
          ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(nc.primary),
              ),
            )
          : (status == AgentStatus.error || status == AgentStatus.timeout)
              ? Icon(Icons.error_outline, size: 13, color: Colors.red)
              : status == AgentStatus.cancelled
                  ? Icon(Icons.stop_circle_outlined, size: 13, color: Colors.grey)
                  : Text(
                      agent.avatar.isNotEmpty ? agent.avatar : agent.name.characters.first,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
    );
  }

  Color get _backgroundColor {
    switch (status) {
      case AgentStatus.thinking:
        return nc.primary.withValues(alpha: 0.2);
      case AgentStatus.replied:
        return nc.success.withValues(alpha: 0.2);
      case AgentStatus.error:
      case AgentStatus.timeout:
        return Colors.red.withValues(alpha: 0.18);
      case AgentStatus.cancelled:
        return Colors.grey.withValues(alpha: 0.18);
      case AgentStatus.idle:
        return nc.primarySurface;
    }
  }

  Color get _borderColor {
    switch (status) {
      case AgentStatus.thinking:
        return nc.primary;
      case AgentStatus.replied:
        return nc.success;
      case AgentStatus.error:
      case AgentStatus.timeout:
        return Colors.red;
      case AgentStatus.cancelled:
        return Colors.grey;
      case AgentStatus.idle:
        return nc.divider;
    }
  }

  Color get _textColor {
    switch (status) {
      case AgentStatus.replied:
        return nc.success;
      case AgentStatus.error:
      case AgentStatus.timeout:
        return Colors.red;
      case AgentStatus.cancelled:
        return Colors.grey;
      default:
        return nc.textSecondary;
    }
  }
}
