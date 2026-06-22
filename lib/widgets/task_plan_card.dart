import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';

/// 聊天中嵌入的任务计划卡片
///
/// 解析 task_plan 工具的输出文本，渲染为可折叠的 checklist
class TaskPlanCard extends StatefulWidget {
  final String planText;
  final AgentColors nc;

  const TaskPlanCard({super.key, required this.planText, required this.nc});

  @override
  State<TaskPlanCard> createState() => _TaskPlanCardState();
}

class _TaskPlanCardState extends State<TaskPlanCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final nc = widget.nc;
    final parsed = _parsePlan(widget.planText);
    if (parsed == null) return const SizedBox.shrink();

    final doneCount = parsed.tasks.where((t) => t.done).length;
    final total = parsed.tasks.length;
    final allDone = doneCount == total;

    return Container(
      margin: const EdgeInsets.only(top: 8),
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
          // Header
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _expanded = !_expanded);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      parsed.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: nc.textPrimary,
                      ),
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
          // Task list
          if (_expanded) ...[
            Divider(height: 1, thickness: 0.5, color: nc.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: parsed.tasks.map((task) => _buildTaskItem(task, nc)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskItem(_TaskEntry task, AgentColors nc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              task.done
                  ? Icons.check_circle
                  : task.inProgress
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
              size: 16,
              color: task.done
                  ? nc.success
                  : task.inProgress
                      ? nc.warning
                      : nc.textSecondary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 8),
          // Task title
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
          // Subtask count
          if (task.subtasks != null && task.subtasks!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: nc.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${task.subtasks!.where((s) => s.done).length}/${task.subtasks!.length}',
                  style: TextStyle(fontSize: 10, color: nc.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  _ParsedPlan? _parsePlan(String text) {
    // 解析标题行: "计划已创建: xxx (n/m 已完成)" 或 "当前进度: xxx (n/m 已完成)"
    final headerMatch = RegExp(r'[:：]\s*(.+?)\s*\((\d+)/(\d+)\s*已完成\)').firstMatch(text);
    if (headerMatch == null) return null;

    final title = headerMatch.group(1)?.trim() ?? '';

    // 解析任务行: "1. ⬜ xxx" 或 "  1.1. ✅ xxx"
    final tasks = <_TaskEntry>[];
    final taskPattern = RegExp(r'^(\s*)(\d+(?:\.\d+)*)\.\s*([⬜🔄✅❌🚫])\s*(.+)$', multiLine: true);

    for (final match in taskPattern.allMatches(text)) {
      final indent = match.group(1)?.length ?? 0;
      final id = match.group(2) ?? '';
      final icon = match.group(3) ?? '';
      final title = match.group(4)?.trim() ?? '';

      final done = icon == '✅';
      final inProgress = icon == '🔄';

      // 根据缩进判断是否为子任务
      if (indent > 0) {
        // 找到父任务并添加子任务
        final parent = tasks.isNotEmpty ? tasks.last : null;
        if (parent != null) {
          parent.subtasks ??= [];
          parent.subtasks!.add(_TaskEntry(id: id, title: title, done: done, inProgress: inProgress));
          continue;
        }
      }

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
  List<_TaskEntry>? subtasks;

  _TaskEntry({
    required this.id,
    required this.title,
    this.done = false,
    this.inProgress = false,
    this.subtasks,
  });
}
