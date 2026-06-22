import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../controllers/chat_controller.dart';

/// 输入框上方的任务计划悬浮面板
///
/// 当 Agent 调用 task_plan 时自动出现，显示当前计划的 checklist
/// 可折叠/展开，实时更新任务状态
class TaskPlanPanel extends StatefulWidget {
  final ChatController controller;
  const TaskPlanPanel({super.key, required this.controller});

  @override
  TaskPlanPanelState createState() => TaskPlanPanelState();
}

class TaskPlanPanelState extends State<TaskPlanPanel> {
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(TaskPlanPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final planText = widget.controller.currentPlanText;
    final nc = AgentColors.of(context);

    // 调试：始终显示当前状态
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: nc.surface,
        border: Border(top: BorderSide(color: nc.divider, width: 0.5)),
      ),
      child: planText == null || planText.isEmpty
          ? Text('DEBUG: planText=null', style: TextStyle(fontSize: 11, color: nc.textSecondary))
          : Text('DEBUG: planText=${planText.length} chars, first 50: ${planText.substring(0, planText.length > 50 ? 50 : planText.length)}',
              style: TextStyle(fontSize: 11, color: nc.textSecondary)),
    );
  }

  Widget _buildTaskItem(_TaskEntry task, AgentColors nc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              task.done
                  ? Icons.check_circle
                  : task.inProgress
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
              size: 14,
              color: task.done
                  ? nc.success
                  : task.inProgress
                      ? nc.warning
                      : nc.textSecondary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 13,
                color: task.done ? nc.textSecondary : nc.textPrimary,
                decoration: task.done ? TextDecoration.lineThrough : null,
                decorationColor: nc.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _ParsedPlan? _parsePlan(String text) {
    final headerMatch = RegExp(r'[:：]\s*(.+?)\s*\((\d+)/(\d+)\s*已完成\)').firstMatch(text);
    if (headerMatch == null) return null;

    final title = headerMatch.group(1)?.trim() ?? '';
    final tasks = <_TaskEntry>[];
    final taskPattern = RegExp(r'^(\s*)(\d+(?:\.\d+)*)\.\s*([⬜🔄✅❌🚫])\s*(.+)$', multiLine: true);

    for (final match in taskPattern.allMatches(text)) {
      final id = match.group(2) ?? '';
      final icon = match.group(3) ?? '';
      final title = match.group(4)?.trim() ?? '';
      final done = icon == '✅';
      final inProgress = icon == '🔄';
      tasks.add(_TaskEntry(id: id, title: title, done: done, inProgress: inProgress));
    }

    if (tasks.isEmpty) return null;
    return _ParsedPlan(title: title, tasks: tasks);
  }
}

class _ParsedPlan {
  final String title;
  final List<_TaskEntry> tasks;
  _ParsedPlan({required this.title, required this.tasks});
}

class _TaskEntry {
  final String id;
  final String title;
  final bool done;
  final bool inProgress;
  _TaskEntry({required this.id, required this.title, this.done = false, this.inProgress = false});
}
