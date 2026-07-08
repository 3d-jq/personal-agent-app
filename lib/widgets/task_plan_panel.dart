import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../tools/task_plan_tool.dart';

/// 可复用的任务计划视图
///
/// [plan] 任务计划数据；[expanded] 是否展开；[onToggle] 折叠/展开回调；[onClose] 关闭回调。
class TaskPlanView extends StatelessWidget {
  final TaskPlan plan;
  final bool expanded;
  final VoidCallback? onToggle;
  final VoidCallback? onClose;

  const TaskPlanView({
    super.key,
    required this.plan,
    this.expanded = true,
    this.onToggle,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final doneCount = plan.tasks
        .where((t) => t.status == TaskStatus.done)
        .length;
    final total = plan.tasks.length;
    final allDoneOrFailed = plan.tasks.every(
      (t) => t.status == TaskStatus.done || t.status == TaskStatus.failed,
    );
    final verified = plan.verified;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: nc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: nc.divider, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - 可点击折叠
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      verified
                          ? Icons.check_circle_outline
                          : allDoneOrFailed
                          ? Icons.hourglass_empty
                          : Icons.check_circle_outline,
                      size: 18,
                      color: verified
                          ? nc.success
                          : allDoneOrFailed
                          ? nc.warning
                          : nc.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: nc.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Progress badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: verified
                            ? nc.success.withValues(alpha: 0.1)
                            : allDoneOrFailed
                            ? nc.warning.withValues(alpha: 0.1)
                            : nc.primarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        verified
                            ? '已完成'
                            : allDoneOrFailed
                            ? '待校验'
                            : '$doneCount/$total',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: verified
                              ? nc.success
                              : allDoneOrFailed
                              ? nc.warning
                              : nc.textSecondary,
                        ),
                      ),
                    ),
                    // 关闭按钮（任务完成后或待校验时显示）
                    if ((verified || allDoneOrFailed) && onClose != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: nc.textSecondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: nc.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    if (onToggle != null && !verified) ...[
                      const SizedBox(width: 4),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: nc.textSecondary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Task list - 可折叠
            if (expanded)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: plan.tasks
                        .map((task) => _buildTaskItem(task, nc))
                        .toList(),
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
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              isDone
                  ? Icons.check_circle_outline
                  : isInProgress
                  ? Icons.radio_button_unchecked
                  : isFailed
                  ? Icons.warning
                  : isBlocked
                  ? Icons.block
                  : Icons.circle_outlined,
              size: 14,
              color: isDone
                  ? nc.success
                  : isInProgress
                  ? nc.primary
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
