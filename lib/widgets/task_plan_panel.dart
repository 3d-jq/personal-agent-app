import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../tools/task_plan_tool.dart';
import '../core/app_animations.dart';

/// 气泡内嵌的任务计划视图（极简 callout 风格）
///
/// 设计为「极简无框气泡」里的内嵌引用块：仅一层极浅中性底色 + 圆角，
/// 无边框、无彩色竖线，与气泡文本流同宽，融入文本而非浮层卡片。
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

    // 徽标配色：进行中=primary，完成=success，待校验=warning
    final badgeBg = verified
        ? nc.success.withValues(alpha: 0.12)
        : allDoneOrFailed
            ? nc.warning.withValues(alpha: 0.12)
            : nc.primary.withValues(alpha: 0.1);
    final badgeFg = verified
        ? nc.success
        : allDoneOrFailed
            ? nc.warning
            : nc.primary;

    return Padding(
      // 左右不缩进 → 与气泡文本同宽；下方留 8 间距与后续文本分隔
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          // 极浅中性底色，无边框、无竖线，仅靠浅底+圆角作为引用块区分，最简洁
          color: nc.primarySurface,
          borderRadius: BorderRadius.circular(12),
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
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                child: Row(
                  children: [
                    (verified || allDoneOrFailed)
                        ? _PopCheck(color: badgeFg)
                        : Icon(Icons.checklist_outlined, size: 17, color: badgeFg),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan.title,
                        style: TextStyle(
                          fontSize: 14.5,
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
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
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
                          color: badgeFg,
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
                            color: nc.textSecondary.withValues(alpha: 0.12),
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
                      const SizedBox(width: 2),
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
                padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
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

/// 计划完成时的对勾微动效（弹簧缩放 + 轻触觉），用于「完成时刻」氛围。
class _PopCheck extends StatefulWidget {
  final Color color;
  const _PopCheck({required this.color});

  @override
  State<_PopCheck> createState() => _PopCheckState();
}

class _PopCheckState extends State<_PopCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppDurations.sheet,
    );
    _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _ctrl.forward();
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Icon(Icons.check_circle_outline, size: 17, color: widget.color),
    );
  }
}
