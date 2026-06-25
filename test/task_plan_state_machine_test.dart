import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/tools/task_plan_tool.dart';
import 'package:personal_agent_app/tools/task_plan_state_machine.dart';

/// Helper to create a plan and its state machine in one call.
TaskPlanStateMachine _sm(List<TaskNode> tasks, {String title = 'Test Plan'}) {
  final plan = TaskPlan(title: title, tasks: tasks);
  return TaskPlanStateMachine(plan);
}

void main() {
  // ── Create-time validation ──────────────────────────────────────────

  group('TaskPlanStateMachine validateCreate', () {
    test('rejects empty task list', () {
      final sm = _sm([]);
      expect(sm.validateCreate(), isNotNull);
    });

    test('rejects duplicate task IDs', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Task 1'),
        TaskNode(id: 'T1', title: 'Task 1 dup'),
      ]);
      expect(sm.validateCreate(), contains('重复'));
    });

    test('rejects parent that does not exist', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Task', parentId: 'T_missing'),
      ]);
      expect(sm.validateCreate(), contains('父任务'));
    });

    test('rejects dependsOn that does not exist', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Task', dependsOn: ['T_missing']),
      ]);
      expect(sm.validateCreate(), contains('依赖'));
    });

    test('rejects self-dependency', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Task', dependsOn: ['T1']),
      ]);
      // Either caught as self-dep or as cycle — both are rejected
      expect(sm.validateCreate(), isNotNull);
    });

    test('rejects parent cycle', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'A', parentId: 'T2'),
        TaskNode(id: 'T2', title: 'B', parentId: 'T1'),
      ]);
      expect(sm.validateCreate(), contains('环'));
    });

    test('rejects dependency cycle', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'A', dependsOn: ['T2']),
        TaskNode(id: 'T2', title: 'B', dependsOn: ['T1']),
      ]);
      expect(sm.validateCreate(), contains('环'));
    });

    test('accepts valid plan', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Parent'),
        TaskNode(id: 'T1.1', title: 'Child', parentId: 'T1'),
        TaskNode(id: 'T2', title: 'Independent', dependsOn: ['T1.1']),
      ]);
      expect(sm.validateCreate(), isNull);
    });

    test('rejects plan with no leaf tasks', () {
      // Every task is a parent of another — no leaves
      final sm = _sm([
        TaskNode(id: 'T1', title: 'A', parentId: 'T2'),
        TaskNode(id: 'T2', title: 'B', parentId: 'T1'),
      ]);
      // This also fails on cycle check, but either way it's rejected
      expect(sm.validateCreate(), isNotNull);
    });
  });

  // ── State transitions ───────────────────────────────────────────────

  group('TaskPlanStateMachine transition', () {
    test('pending → inProgress succeeds', () {
      final sm = _sm([TaskNode(id: 'T1', title: 'Task')]);
      final result = sm.transition('T1', TaskStatus.inProgress);
      expect(result.ok, isTrue);
      expect(sm.plan.findTask('T1')!.status, TaskStatus.inProgress);
    });

    test('pending → inProgress rejected when dependency not done', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Dep'),
        TaskNode(id: 'T2', title: 'Task', dependsOn: ['T1']),
      ]);
      final result = sm.transition('T2', TaskStatus.inProgress);
      expect(result.ok, isFalse);
      expect(result.error, contains('依赖未完成'));
    });

    test('pending → inProgress succeeds after dependency done', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Dep'),
        TaskNode(id: 'T2', title: 'Task', dependsOn: ['T1']),
      ]);
      sm.transition('T1', TaskStatus.done);
      final result = sm.transition('T2', TaskStatus.inProgress);
      expect(result.ok, isTrue);
    });

    test('rejects multiple in_progress leaves', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'A'),
        TaskNode(id: 'T2', title: 'B'),
      ]);
      sm.transition('T1', TaskStatus.inProgress);
      final result = sm.transition('T2', TaskStatus.inProgress);
      expect(result.ok, isFalse);
      expect(result.error, contains('已有其他叶子任务'));
    });

    test('rejects parent done when children not done', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Parent'),
        TaskNode(id: 'T1.1', title: 'Child', parentId: 'T1'),
      ]);
      final result = sm.transition('T1', TaskStatus.done);
      expect(result.ok, isFalse);
      expect(result.error, contains('子任务未完成'));
    });

    test('parent done succeeds after all children done', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Parent'),
        TaskNode(id: 'T1.1', title: 'Child A', parentId: 'T1'),
        TaskNode(id: 'T1.2', title: 'Child B', parentId: 'T1'),
      ]);
      sm.transition('T1.1', TaskStatus.inProgress);
      sm.transition('T1.1', TaskStatus.done);
      sm.transition('T1.2', TaskStatus.inProgress);
      sm.transition('T1.2', TaskStatus.done);
      // both children done → parent auto-synced to done
      expect(sm.plan.findTask('T1')!.status, TaskStatus.done);
    });

    test('done cannot regress to in_progress', () {
      final sm = _sm([TaskNode(id: 'T1', title: 'Task')]);
      sm.transition('T1', TaskStatus.done);
      final result = sm.transition('T1', TaskStatus.inProgress);
      expect(result.ok, isFalse);
      expect(result.error, contains('不可回退'));
    });

    test('failed cannot regress', () {
      final sm = _sm([TaskNode(id: 'T1', title: 'Task')]);
      sm.transition('T1', TaskStatus.failed, note: 'boom');
      final result = sm.transition('T1', TaskStatus.inProgress);
      expect(result.ok, isFalse);
      expect(result.error, contains('不可回退'));
    });

    test('done → done is idempotent (ok, no error)', () {
      final sm = _sm([TaskNode(id: 'T1', title: 'Task')]);
      sm.transition('T1', TaskStatus.done);
      final result = sm.transition('T1', TaskStatus.done);
      expect(result.ok, isTrue);
      expect(result.error, isNull);
    });

    test('pending → blocked requires reason', () {
      final sm = _sm([TaskNode(id: 'T1', title: 'Task')]);
      final noReason = sm.transition('T1', TaskStatus.blocked);
      expect(noReason.ok, isFalse);

      final withReason = sm.transition(
        'T1',
        TaskStatus.blocked,
        blockedReason: 'API down',
      );
      expect(withReason.ok, isTrue);
      expect(sm.plan.findTask('T1')!.blockedReason, 'API down');
    });

    test('blocked → inProgress clears blockedReason', () {
      final sm = _sm([TaskNode(id: 'T1', title: 'Task')]);
      sm.transition('T1', TaskStatus.blocked, blockedReason: 'waiting');
      sm.transition('T1', TaskStatus.inProgress);
      expect(sm.plan.findTask('T1')!.status, TaskStatus.inProgress);
      expect(sm.plan.findTask('T1')!.blockedReason, isNull);
    });

    test('rejects child in_progress when parent is failed', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Parent'),
        TaskNode(id: 'T1.1', title: 'Child', parentId: 'T1'),
      ]);
      sm.transition('T1', TaskStatus.failed, note: 'parent dead');
      final result = sm.transition('T1.1', TaskStatus.inProgress);
      expect(result.ok, isFalse);
      expect(result.error, contains('父任务'));
    });

    test('failing a child syncs parent to failed', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Parent'),
        TaskNode(id: 'T1.1', title: 'Child A', parentId: 'T1'),
        TaskNode(id: 'T1.2', title: 'Child B', parentId: 'T1'),
      ]);
      sm.transition('T1.1', TaskStatus.inProgress);
      sm.transition('T1.1', TaskStatus.failed, note: 'child A boom');
      expect(sm.plan.findTask('T1')!.status, TaskStatus.failed);
    });

    test('blocked child syncs parent to blocked (when no in_progress sibling)', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Parent'),
        TaskNode(id: 'T1.1', title: 'Child', parentId: 'T1'),
      ]);
      sm.transition('T1.1', TaskStatus.blocked, blockedReason: 'stuck');
      expect(sm.plan.findTask('T1')!.status, TaskStatus.blocked);
    });
  });

  // ── Advance ─────────────────────────────────────────────────────────

  group('TaskPlanStateMachine advance', () {
    test('completes current and advances to next ready leaf', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'A'),
        TaskNode(id: 'T2', title: 'B'),
      ]);
      sm.transition('T1', TaskStatus.inProgress);
      final result = sm.advance();
      expect(result.ok, isTrue);
      expect(sm.plan.findTask('T1')!.status, TaskStatus.done);
      expect(sm.plan.findTask('T2')!.status, TaskStatus.inProgress);
    });

    test('skips tasks with unsatisfied dependencies, picks next ready', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Dep'),
        TaskNode(id: 'T2', title: 'A', dependsOn: ['T1']),
        TaskNode(id: 'T3', title: 'B'),
      ]);
      sm.transition('T1', TaskStatus.inProgress);
      sm.advance(); // T1 done → T2 dep is now satisfied, so T2 goes next
      expect(sm.plan.findTask('T2')!.status, TaskStatus.inProgress);
      expect(sm.plan.findTask('T3')!.status, TaskStatus.pending);
    });

    test('reports all done message when complete', () {
      final sm = _sm([TaskNode(id: 'T1', title: 'Only')]);
      sm.transition('T1', TaskStatus.inProgress);
      final result = sm.advance();
      expect(result.ok, isTrue);
      expect(result.message, contains('verify'));
    });

    test('auto-starts first pending leaf when none in_progress', () {
      final sm = _sm([TaskNode(id: 'T1', title: 'Only')]);
      // No task is in_progress
      final result = sm.advance();
      expect(result.ok, isTrue);
      expect(sm.plan.findTask('T1')!.status, TaskStatus.inProgress);
    });
  });

  // ── Verify ──────────────────────────────────────────────────────────

  group('TaskPlanStateMachine verify', () {
    test('passes when all done', () {
      final sm = _sm([TaskNode(id: 'T1', title: 'Done')]);
      sm.transition('T1', TaskStatus.done);
      final result = sm.verify();
      expect(result.passed, isTrue);
      expect(sm.plan.verified, isTrue);
    });

    test('passes when all done or failed', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Done'),
        TaskNode(id: 'T2', title: 'Failed'),
      ]);
      sm.transition('T1', TaskStatus.done);
      sm.transition('T2', TaskStatus.failed, note: 'boom');
      final result = sm.verify();
      expect(result.passed, isTrue);
    });

    test('fails with recovery path when tasks remain', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Pending'),
        TaskNode(id: 'T2', title: 'Blocked'),
      ]);
      sm.transition('T2', TaskStatus.blocked, blockedReason: 'API down');
      final result = sm.verify();
      expect(result.passed, isFalse);
      expect(result.message, contains('T1'));
      expect(result.message, contains('T2'));
      expect(result.message, contains('blocked'));
      expect(result.message, contains('推荐操作'));
    });

    test('fails when a task is still in_progress', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Running'),
      ]);
      sm.transition('T1', TaskStatus.inProgress);
      final result = sm.verify();
      expect(result.passed, isFalse);
      expect(result.message, contains('T1'));
    });
  });

  // ── JSON migration compatibility ────────────────────────────────────

  group('TaskPlan JSON migration', () {
    test('loads old v0 plan (no schemaVersion, no dependsOn)', () {
      final json = {
        'title': 'Old Plan',
        'tasks': [
          {'id': 'T1', 'title': 'Task 1', 'status': 'done'},
          {'id': 'T1.1', 'title': 'Child', 'parentId': 'T1', 'status': 'pending'},
        ],
        'verified': false,
      };
      final plan = TaskPlan.fromJson(json);
      expect(plan.title, 'Old Plan');
      expect(plan.tasks.length, 2);
      expect(plan.tasks[0].dependsOn, isEmpty);
      expect(plan.tasks[0].blockedReason, isNull);
      expect(plan.tasks[1].dependsOn, isEmpty);
    });

    test('new plan roundtrips with schemaVersion', () {
      final plan = TaskPlan(
        title: 'New Plan',
        tasks: [
          TaskNode(
            id: 'T1',
            title: 'Task',
            dependsOn: [],
            blockedReason: null,
          ),
        ],
      );
      final json = plan.toJson();
      expect(json['schemaVersion'], taskPlanSchemaVersion);

      final restored = TaskPlan.fromJson(json);
      expect(restored.title, 'New Plan');
      expect(restored.tasks[0].dependsOn, isEmpty);
    });
  });

  // ── firstExecutableLeaf ─────────────────────────────────────────────

  group('TaskPlanStateMachine firstExecutableLeaf', () {
    test('returns first pending leaf with no deps', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'A'),
        TaskNode(id: 'T2', title: 'B'),
      ]);
      final leaf = sm.firstExecutableLeaf();
      expect(leaf?.id, 'T1');
    });

    test('skips leaves with unsatisfied deps', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Dep'),
        TaskNode(id: 'T2', title: 'A', dependsOn: ['T1']),
      ]);
      final leaf = sm.firstExecutableLeaf();
      expect(leaf?.id, 'T1'); // T2 blocked by dep
    });

    test('returns null when all leaves blocked', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'A', dependsOn: ['T_missing']),
      ]);
      final leaf = sm.firstExecutableLeaf();
      expect(leaf, isNull);
    });

    test('skips non-leaf (parent) tasks', () {
      final sm = _sm([
        TaskNode(id: 'T1', title: 'Parent'),
        TaskNode(id: 'T1.1', title: 'Child', parentId: 'T1'),
      ]);
      final leaf = sm.firstExecutableLeaf();
      expect(leaf?.id, 'T1.1'); // T1 is parent, not leaf
    });
  });
}
