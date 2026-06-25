import 'task_plan_tool.dart';

/// Result of a state transition attempt.
class TransitionResult {
  final bool ok;
  final String? error;
  final String? warning;

  const TransitionResult.ok({this.warning}) : ok = true, error = null;
  const TransitionResult.error(this.error, {this.warning}) : ok = false;
}

/// Result of verify().
class VerifyResult {
  final bool passed;
  final String message;

  const VerifyResult(this.passed, this.message);
}

/// Result of advance().
class AdvanceResult {
  final bool ok;
  final String message;
  final String? nextTaskId;

  const AdvanceResult(this.ok, this.message, {this.nextTaskId});
}

/// Pure state machine for TaskPlan.
///
/// All state mutations must go through this machine; it enforces:
/// - Valid state transitions (no skip-step, no multi-in_progress leaf)
/// - Dependency checks (dependsOn must be all done before starting)
/// - Parent-child sync (parent done only when all children done)
/// - Create-time validation (unique IDs, no cycles, valid refs)
class TaskPlanStateMachine {
  final TaskPlan plan;

  TaskPlanStateMachine(this.plan);

  // ── create-time validation ──────────────────────────────────────────

  /// Validates the task list at create time.
  /// Returns null if valid, or an error message.
  String? validateCreate() {
    final tasks = plan.tasks;
    if (tasks.isEmpty) return '任务列表为空';

    // 1. Unique IDs
    final ids = <String>{};
    for (final t in tasks) {
      if (ids.contains(t.id)) return '任务ID ${t.id} 重复';
      ids.add(t.id);
    }

    // 2. parent must exist
    for (final t in tasks) {
      if (t.parentId != null && !ids.contains(t.parentId)) {
        return '任务 ${t.id} 的父任务 ${t.parentId} 不存在';
      }
    }

    // 3. dependsOn must exist
    for (final t in tasks) {
      for (final dep in t.dependsOn) {
        if (!ids.contains(dep)) {
          return '任务 ${t.id} 的依赖 $dep 不存在';
        }
      }
    }

    // 4. No parent cycles
    for (final t in tasks) {
      String? p = t.parentId;
      final visited = <String>{};
      while (p != null) {
        if (!visited.add(p)) return '任务 ${t.id} 的父子关系存在环';
        p = tasks.cast<TaskNode?>().firstWhere(
              (x) => x?.id == p,
              orElse: () => null,
            )?.parentId;
      }
    }

    // 5. No dependency cycles
    for (final t in tasks) {
      final stack = <String>[t.id];
      final visiting = <String>{t.id};
      final err = _checkDepCycle(t.id, tasks, visiting, stack);
      if (err != null) return err;
    }

    // 6. dep cannot point to self
    for (final t in tasks) {
      if (t.dependsOn.contains(t.id)) {
        return '任务 ${t.id} 不能依赖自身';
      }
    }

    // 7. At least one leaf task
    final leafCount = tasks.where((t) => t.isLeaf(tasks)).length;
    if (leafCount == 0) return '任务计划必须至少有一个叶子任务';

    return null; // valid
  }

  String? _checkDepCycle(
    String id,
    List<TaskNode> tasks,
    Set<String> visiting,
    List<String> stack,
  ) {
    final task = tasks.cast<TaskNode?>().firstWhere(
          (t) => t?.id == id,
          orElse: () => null,
        );
    if (task == null) return null;
    for (final dep in task.dependsOn) {
      if (visiting.contains(dep)) {
        stack.add(dep);
        return '依赖存在环: ${stack.join(' → ')}';
      }
      visiting.add(dep);
      stack.add(dep);
      final err = _checkDepCycle(dep, tasks, visiting, stack);
      if (err != null) return err;
      stack.removeLast();
      visiting.remove(dep);
    }
    return null;
  }

  /// Returns the first pending leaf task that is ready to execute,
  /// or null if none are ready.
  TaskNode? firstExecutableLeaf() {
    final leaves = plan.tasks.where((t) => t.isLeaf(plan.tasks)).toList();
    for (final leaf in leaves) {
      if (leaf.status != TaskStatus.pending) continue;
      if (!_depsSatisfied(leaf)) continue;
      if (!_parentCanProgress(leaf)) continue;
      return leaf;
    }
    return null;
  }

  // ── state transitions ───────────────────────────────────────────────

  /// Attempt to transition [taskId] to [newStatus].
  TransitionResult transition(
    String taskId,
    TaskStatus newStatus, {
    String? note,
    String? blockedReason,
  }) {
    final task = plan.findTask(taskId);
    if (task == null) return TransitionResult.error('找不到任务 $taskId');

    final old = task.status;

    // Idempotent cases
    if (old == newStatus) {
      // done → done, failed → failed: allow silently
      if (old == TaskStatus.done || old == TaskStatus.failed) {
        return const TransitionResult.ok();
      }
      // pending → pending, inProgress → inProgress, blocked → blocked: warn
      return TransitionResult.ok(
        warning: '任务 $taskId 已经是 $newStatus 状态',
      );
    }

    // Forbidden: done / failed cannot regress
    if (old == TaskStatus.done || old == TaskStatus.failed) {
      return TransitionResult.error(
        '任务 $taskId 已${old == TaskStatus.done ? '完成' : '失败'}，不可回退',
      );
    }

    // Check target transition validity
    switch (newStatus) {
      case TaskStatus.pending:
        return TransitionResult.error('不允许将任务回退到 pending 状态');

      case TaskStatus.inProgress:
        return _transitionToInProgress(task, note);

      case TaskStatus.done:
        return _transitionToDone(task, note);

      case TaskStatus.failed:
        return _transitionToFailed(task, note, blockedReason);

      case TaskStatus.blocked:
        return _transitionToBlocked(task, note, blockedReason);
    }
  }

  TransitionResult _transitionToInProgress(TaskNode task, String? note) {
    // Must satisfy dependencies
    if (!_depsSatisfied(task)) {
      final unmet = task.dependsOn
          .where((depId) {
            final d = plan.findTask(depId);
            return d == null || d.status != TaskStatus.done;
          })
          .join(', ');
      return TransitionResult.error(
        '任务 ${task.id} 的依赖未完成: $unmet',
      );
    }

    // Parent must be able to progress
    if (!_parentCanProgress(task)) {
      final parent = plan.findTask(task.parentId!);
      return TransitionResult.error(
        '父任务 ${task.parentId} 状态为 ${parent?.status.name}，不能推进子任务',
      );
    }

    // No other leaf task already in_progress
    final leaves = plan.tasks.where((t) => t.isLeaf(plan.tasks)).toList();
    final otherInProgress = leaves.where(
      (t) => t.id != task.id && t.status == TaskStatus.inProgress,
    );
    if (otherInProgress.isNotEmpty) {
      final ids = otherInProgress.map((t) => t.id).join(', ');
      return TransitionResult.error(
        '已有其他叶子任务正在执行中: $ids。请先完成或阻塞它们再开始新任务。',
      );
    }

    // Apply transition
    task.status = TaskStatus.inProgress;
    if (note != null) task.note = note;
    if (task.blockedReason != null) task.blockedReason = null; // clear block
    _syncParents(task);
    return const TransitionResult.ok();
  }

  TransitionResult _transitionToDone(TaskNode task, String? note) {
    // If parent task: all children must be done
    final children = plan.tasks.where((t) => t.parentId == task.id).toList();
    if (children.isNotEmpty) {
      final notDone = children.where(
        (c) => c.status != TaskStatus.done && c.status != TaskStatus.failed,
      );
      if (notDone.isNotEmpty) {
        final ids = notDone.map((c) => c.id).join(', ');
        return TransitionResult.error(
          '父任务 ${task.id} 不能直接标记为完成，还有子任务未完成: $ids',
        );
      }
    }

    task.status = TaskStatus.done;
    if (note != null) task.note = note;
    _syncParents(task);
    return const TransitionResult.ok();
  }

  TransitionResult _transitionToFailed(
    TaskNode task,
    String? note,
    String? blockedReason,
  ) {
    if ((note == null || note.isEmpty) && (blockedReason == null || blockedReason.isEmpty)) {
      return TransitionResult.error(
        '将任务设为 failed 时必须提供 note 说明原因',
      );
    }
    task.status = TaskStatus.failed;
    if (note != null) task.note = note;
    if (blockedReason != null) task.blockedReason = blockedReason;
    _syncParents(task);
    return const TransitionResult.ok();
  }

  TransitionResult _transitionToBlocked(
    TaskNode task,
    String? note,
    String? blockedReason,
  ) {
    if ((note == null || note.isEmpty) && (blockedReason == null || blockedReason.isEmpty)) {
      return TransitionResult.error(
        '将任务设为 blocked 时必须提供 note 或 blockedReason 说明阻塞原因',
      );
    }
    task.status = TaskStatus.blocked;
    if (note != null) task.note = note;
    if (blockedReason != null) task.blockedReason = blockedReason;
    _syncParents(task);
    return const TransitionResult.ok();
  }

  // ── advance ──────────────────────────────────────────────────────────

  /// Completes the current in_progress leaf task and picks the next ready leaf.
  AdvanceResult advance() {
    // 1. Find current in_progress leaf
    final leaves = plan.tasks.where((t) => t.isLeaf(plan.tasks)).toList();
    final current = leaves.where((t) => t.status == TaskStatus.inProgress);

    if (current.isEmpty) {
      // No in_progress leaf — check if we have ready pending leaves
      final next = firstExecutableLeaf();
      if (next != null) {
        next.status = TaskStatus.inProgress;
        _syncParents(next);
        return AdvanceResult(
          true,
          '没有正在执行的任务，已自动将 ${next.id} "${next.title}" 设为进行中',
          nextTaskId: next.id,
        );
      }
      // Nothing ready — report blockers
      return AdvanceResult(
        false,
        _buildBlockedReport(),
      );
    }

    if (current.length > 1) {
      // Multiple in_progress leaves — auto-repair
      final ids = current.map((t) => t.id).join(', ');
      return AdvanceResult(
        false,
        '检测到多个叶子任务正在执行: $ids。请用 update 明确将某个设为 done/failed/blocked 后再 advance。',
      );
    }

    final cur = current.first;
    cur.status = TaskStatus.done;
    _syncParents(cur);

    // Find next ready leaf
    final next = firstExecutableLeaf();
    if (next != null) {
      next.status = TaskStatus.inProgress;
      _syncParents(next);
      return AdvanceResult(
        true,
        '✅ 已完成 ${cur.id} "${cur.title}"，下一步: ${next.id} "${next.title}"',
        nextTaskId: next.id,
      );
    }

    // Check if everything is done or failed
    final allDoneOrFailed = plan.tasks.every(
      (t) => t.status == TaskStatus.done || t.status == TaskStatus.failed,
    );
    if (allDoneOrFailed) {
      return AdvanceResult(
        true,
        '✅ 已完成 ${cur.id} "${cur.title}"\n⚠️ 所有步骤已完成，请调用 verify 校验通过后再输出最终答案。',
      );
    }

    // Some tasks remain but none are ready
    return AdvanceResult(
      true,
      '✅ 已完成 ${cur.id} "${cur.title}"\n'
      '${_buildBlockedReport()}',
    );
  }

  String _buildBlockedReport() {
    final pending = plan.tasks
        .where((t) =>
            t.status == TaskStatus.pending || t.status == TaskStatus.blocked)
        .toList();
    if (pending.isEmpty) return '没有等待中的任务';

    final buf = StringBuffer();
    buf.writeln('以下任务尚未就绪:');
    for (final t in pending) {
      final reasons = <String>[];
      if (t.status == TaskStatus.blocked) {
        reasons.add('已阻塞${t.blockedReason != null ? ': ${t.blockedReason}' : ''}');
      }
      for (final dep in t.dependsOn) {
        final d = plan.findTask(dep);
        if (d != null && d.status != TaskStatus.done) {
          reasons.add('依赖 ${d.id} "${d.title}" 未完成 (当前: ${d.status.name})');
        }
      }
      if (t.parentId != null) {
        final p = plan.findTask(t.parentId!);
        if (p != null &&
            p.status != TaskStatus.inProgress &&
            p.status != TaskStatus.done) {
          reasons.add('父任务 ${p.id} 状态为 ${p.status.name}');
        }
      }
      final reasonText = reasons.isEmpty ? '原因未知' : reasons.join('; ');
      buf.writeln('  ⬜ ${t.id} "${t.title}" — $reasonText');
    }
    buf.writeln('\n建议:');
    buf.writeln('  - update(task_id, blocked, blockedReason) — 阻塞无法推进的任务');
    buf.writeln('  - update(task_id, failed, note) — 标记失败');
    buf.writeln('  - update(task_id, in_progress) — 手动启动（需满足依赖）');
    return buf.toString();
  }

  // ── verify ───────────────────────────────────────────────────────────

  /// Verifies that all tasks are done or failed, and returns actionable
  /// recovery paths if not.
  VerifyResult verify() {
    final notDone = plan.tasks
        .where((t) =>
            t.status != TaskStatus.done && t.status != TaskStatus.failed)
        .toList();

    if (notDone.isEmpty) {
      // Also check parent-child consistency
      final inconsistent = <String>[];
      for (final t in plan.tasks) {
        final children = plan.tasks.where((c) => c.parentId == t.id).toList();
        if (children.isNotEmpty) {
          if (children.every((c) => c.status == TaskStatus.done) &&
              t.status != TaskStatus.done) {
            inconsistent.add('父任务 ${t.id} 应为 done (子任务已全部完成)');
          }
          if (children.any((c) => c.status == TaskStatus.inProgress) &&
              t.status != TaskStatus.inProgress) {
            inconsistent.add('父任务 ${t.id} 应为 in_progress (有子任务进行中)');
          }
        }
      }
      if (inconsistent.isNotEmpty) {
        return VerifyResult(
          false,
          '❌ 校验失败！父子任务状态不一致:\n${inconsistent.map((s) => '  - $s').join('\n')}\n'
          '请用 update 修复后再 verify。',
        );
      }
      plan.verified = true;
      return const VerifyResult(
        true,
        '✅ 校验通过！所有任务已完成，现在可以输出最终答案了。',
      );
    }

    plan.verified = false;

    // Build detailed recovery report
    final buf = StringBuffer();
    buf.writeln('❌ 校验失败！还有 ${notDone.length} 个任务未完成:');
    buf.writeln();

    for (final t in notDone) {
      final statusLabel = switch (t.status) {
        TaskStatus.pending => '待开始',
        TaskStatus.inProgress => '进行中',
        TaskStatus.blocked => '已阻塞',
        _ => t.status.name,
      };
      buf.write('  ${t.id} "${t.title}" — $statusLabel');

      if (t.blockedReason != null) {
        buf.write(' | 阻塞原因: ${t.blockedReason}');
      }
      buf.writeln();

      // Show unmet dependencies
      final unmetDeps = t.dependsOn
          .where((depId) {
            final d = plan.findTask(depId);
            return d == null || d.status != TaskStatus.done;
          })
          .toList();
      if (unmetDeps.isNotEmpty) {
        buf.writeln('    未满足依赖: ${unmetDeps.join(', ')}');
      }
    }

    buf.writeln();
    buf.writeln('📋 推荐操作:');
    buf.writeln('  - 如有阻塞任务: update(task_id, blocked, blockedReason)');
    buf.writeln('  - 如有失败任务: update(task_id, failed, note)');
    buf.writeln('  - 如可继续: advance() 或 update(task_id, in_progress)');
    buf.writeln('  - 完成后再次调用 verify');

    return VerifyResult(false, buf.toString());
  }

  // ── parent sync ──────────────────────────────────────────────────────

  /// Recursively sync parent status based on children statuses.
  void _syncParents(TaskNode task) {
    final parentId = task.parentId;
    if (parentId == null) return;
    final parent = plan.findTask(parentId);
    if (parent == null) return;

    final children = plan.tasks.where((t) => t.parentId == parentId).toList();
    if (children.isEmpty) return;

    if (children.every((c) => c.status == TaskStatus.done)) {
      parent.status = TaskStatus.done;
    } else if (children.any((c) => c.status == TaskStatus.failed)) {
      parent.status = TaskStatus.failed;
    } else if (children.any((c) => c.status == TaskStatus.blocked) &&
        !children.any((c) => c.status == TaskStatus.inProgress)) {
      parent.status = TaskStatus.blocked;
    } else if (children.any((c) => c.status == TaskStatus.inProgress)) {
      parent.status = TaskStatus.inProgress;
    } else {
      parent.status = TaskStatus.pending;
    }

    // Recurse up
    _syncParents(parent);
  }

  // ── helpers ───────────────────────────────────────────────────────────

  bool _depsSatisfied(TaskNode task) {
    for (final depId in task.dependsOn) {
      final dep = plan.findTask(depId);
      if (dep == null || dep.status != TaskStatus.done) return false;
    }
    return true;
  }

  bool _parentCanProgress(TaskNode task) {
    if (task.parentId == null) return true;
    final parent = plan.findTask(task.parentId!);
    if (parent == null) return true;
    // Parent must be in_progress, done, or pending (not failed/blocked)
    return parent.status != TaskStatus.failed &&
        parent.status != TaskStatus.blocked;
  }
}
