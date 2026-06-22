import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../controllers/chat_controller.dart';
import '../services/chat_stream_event.dart';
import '../tools/task_plan_tool.dart';

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
    final plan = widget.controller.currentPlan;
    if (plan == null) return const SizedBox.shrink();
    final nc = AgentColors.of(context);

    final doneCount = plan.tasks.where((t) => t.status == TaskStatus.done).length;
    final total = plan.tasks.length;
    final allDone = doneCount == total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: nc.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: nc.divider, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - 可点击折叠
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _expanded = !_expanded);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      allDone ? Icons.check_circle : Icons.task_alt,
                      size: 18,
                      color: allDone ? nc.success : nc.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: nc.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Progress badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: allDone
                            ? nc.success.withValues(alpha: 0.1)
                            : nc.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$doneCount/$total',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: allDone ? nc.success : nc.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: nc.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            // Task list - 可折叠
            if (_expanded)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: plan.tasks.map((task) => _buildTaskItem(task, nc)).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(TaskNode task, AgentColors nc) {
    final isDone = task.status == TaskStatus.done;
    final isInProgress = task.status == TaskStatus.inProgress;
    final isFailed = task.status == TaskStatus.failed;
    final isBlocked = task.status == TaskStatus.blocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              isDone
                  ? Icons.check_circle
                  : isInProgress
                      ? Icons.radio_button_checked
                      : isFailed
                          ? Icons.error
                          : isBlocked
                              ? Icons.block
                              : Icons.radio_button_unchecked,
              size: 14,
              color: isDone
                  ? nc.success
                  : isInProgress
                      ? nc.warning
                      : isFailed
                          ? nc.error
                          : nc.textSecondary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 13,
                color: isDone ? nc.textSecondary : nc.textPrimary,
                decoration: isDone ? TextDecoration.lineThrough : null,
                decorationColor: nc.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
