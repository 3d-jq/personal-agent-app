import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'base_tool.dart';
import 'task_plan_tool.g.dart';
import 'task_plan_state_machine.dart';
import '../core/service_locator.dart';
import '../services/log_service.dart';
import '../services/virtual_fs.dart';

/// 任务计划工具：帮助大模型在执行复杂多步任务时保持进度。
///
/// 支持：
/// - 创建计划（含子任务树）
/// - 更新任务状态（pending/in_progress/done/failed/blocked）
/// - advance 自动推进当前 in_progress 任务
/// - 任务持久化到虚拟文件系统
/// - 查看当前进度摘要
class TaskPlanTool extends AgentTool {
  TaskPlan? _currentPlan;
  TaskPlan? get currentPlan => _currentPlan;

  String? lastStatusText;

  /// 串行锁：所有 task_plan 操作必须串行执行，保护 _currentPlan / lastStatusText / plan.json
  Future<void> _queue = Future.value();

  @override
  String get name => 'task_plan';

  @override
  String get description => taskPlanToolDescription;

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['create', 'update', 'advance', 'status', 'clear', 'verify'],
        'description':
            'create: 创建新计划; update: 更新任务状态; '
            'advance: 自动完成当前 in_progress 任务并推进到下一步; '
            'status: 查看进度; clear: 清除计划; '
            'verify: 校验所有任务是否已完成/失败，通过后才能输出最终答案',
      },
      'title': {'type': 'string', 'description': '计划标题（仅 create 时必填）'},
      'tasks': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string', 'description': '任务ID，如 T1, T2, T1.1'},
            'title': {'type': 'string', 'description': '任务描述'},
            'parent': {'type': 'string', 'description': '父任务ID（可选，用于子任务）'},
            'dependsOn': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': '依赖的任务ID列表（可选），这些任务必须全部 done 后才能开始本任务',
            },
          },
          'required': ['id', 'title'],
        },
        'description': '任务列表（仅 create 时使用），支持通过 parent 字段构建子任务树，dependsOn 指定依赖',
      },
      'task_id': {
        'type': 'string',
        'description': '任务ID（仅 update 时必填），如 T1, T1.1',
      },
      'status': {
        'type': 'string',
        'enum': ['pending', 'in_progress', 'done', 'failed', 'blocked'],
        'description': '新状态（仅 update 时使用）',
      },
      'note': {'type': 'string', 'description': '状态更新备注（可选）'},
      'blockedReason': {'type': 'string', 'description': '阻塞原因（仅 blocked 或 failed 状态时推荐填写）'},
    },
    'required': ['action'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    // 串行锁：所有操作排队执行，防止竞态条件
    final prev = _queue;
    final completer = Completer<String>();
    _queue = prev.then((_) async {
      // Prevent unhandled exceptions from deadlocking the queue
      try {
        final result = await _executeLocked(args);
        if (!completer.isCompleted) completer.complete(result);
      } catch (e) {
        if (!completer.isCompleted) completer.complete('执行失败: $e');
      }
    });
    return completer.future;
  }

  Future<String> _executeLocked(Map<String, dynamic> args) async {
    final action = args['action'] as String? ?? '';

    if (_currentPlan == null) {
      await _loadPlan();
    }

    switch (action) {
      case 'create':
        final result = await _create(args);
        lastStatusText = result;
        return result;
      case 'update':
        final result = await _update(args);
        lastStatusText = result;
        return result;
      case 'advance':
        final result = await _advance();
        lastStatusText = result;
        return result;
      case 'status':
        final result = _status();
        lastStatusText = result;
        return result;
      case 'clear':
        final result = await _clear();
        lastStatusText = result;
        return result;
      case 'verify':
        final result = await _verify();
        lastStatusText = result;
        return result;
      default:
        return '错误: action 必须为 create / update / advance / status / clear / verify 之一';
    }
  }

  Future<String> _create(Map<String, dynamic> args) async {
    final title = (args['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return '错误: 创建计划需要提供 title';

    final rawTasks = (args['tasks'] as List?) ?? [];
    if (rawTasks.isEmpty) return '错误: 创建计划需要提供 tasks 列表';

    final tasks = <TaskNode>[];
    for (final raw in rawTasks) {
      if (raw is! Map) continue;
      final id = raw['id'] as String? ?? '';
      final taskTitle = raw['title'] as String? ?? '';
      final parent = raw['parent'] as String?;
      final deps = (raw['dependsOn'] as List?)?.cast<String>() ?? const <String>[];
      if (id.isEmpty || taskTitle.isEmpty) continue;
      if (tasks.any((t) => t.id == id)) {
        return '错误: 任务ID $id 重复，请使用唯一ID';
      }
      tasks.add(TaskNode(id: id, title: taskTitle, parentId: parent, dependsOn: deps));
    }

    if (tasks.isEmpty) return '错误: 没有有效的任务项';

    _currentPlan = TaskPlan(title: title, tasks: tasks, verified: false);

    // 通过状态机校验创建合法性
    final sm = TaskPlanStateMachine(_currentPlan!);
    final validationErr = sm.validateCreate();
    if (validationErr != null) {
      _currentPlan = null;
      return '❌ 计划创建失败: $validationErr';
    }

    // 自动将第一个可执行叶子任务设为 in_progress
    final first = sm.firstExecutableLeaf();
    if (first != null) {
      first.status = TaskStatus.inProgress;
    } else {
      // 无可执行叶子 → 返回阻塞原因
      _currentPlan = null;
      return '❌ 计划创建失败: 没有可执行的任务。请检查依赖关系是否正确。';
    }

    await _savePlan();
    return _formatProgressWithRemaining('计划已创建');
  }

  Future<String> _update(Map<String, dynamic> args) async {
    if (_currentPlan == null) return '当前没有活跃计划，请先用 create 创建';

    final taskId = args['task_id'] as String?;
    if (taskId == null || taskId.isEmpty) return '错误: update 需要提供 task_id';

    final newStatusStr = args['status'] as String?;
    if (newStatusStr == null) return '错误: update 需要提供 status';

    final newStatus = _parseStatus(newStatusStr);
    if (newStatus == null) {
      return '错误: status 必须为 pending / in_progress / done / failed / blocked 之一';
    }

    final note = args['note'] as String?;
    final blockedReason = args['blockedReason'] as String?;

    final sm = TaskPlanStateMachine(_currentPlan!);
    final result = sm.transition(
      taskId,
      newStatus,
      note: note,
      blockedReason: blockedReason,
    );

    if (!result.ok) {
      final warn = result.warning != null ? '\n⚠️ ${result.warning}' : '';
      return '❌ ${result.error}$warn';
    }

    _currentPlan!.verified = false;
    await _savePlan();

    final warn = result.warning != null ? '\n⚠️ ${result.warning}' : '';
    final msg = StringBuffer()
      ..write('任务 $taskId 已更新为 $newStatusStr$warn');
    return _formatProgressWithRemaining(msg.toString());
  }

  TaskStatus? _parseStatus(String s) => switch (s) {
    'pending' => TaskStatus.pending,
    'in_progress' => TaskStatus.inProgress,
    'done' => TaskStatus.done,
    'failed' => TaskStatus.failed,
    'blocked' => TaskStatus.blocked,
    _ => null,
  };

  Future<String> _advance() async {
    if (_currentPlan == null) {
      return '错误: 当前没有活跃计划，请先用 create 创建';
    }

    final sm = TaskPlanStateMachine(_currentPlan!);
    final result = sm.advance();

    _currentPlan!.verified = false;
    await _savePlan();

    if (!result.ok) {
      return result.message;
    }

    return _formatProgressWithRemaining(result.message);
  }

  String _status() {
    if (_currentPlan == null) return '当前没有活跃计划';
    return _formatProgressWithRemaining('当前进度');
  }

  Future<String> _clear() async {
    if (_currentPlan == null) return '当前没有活跃计划';

    if (!_currentPlan!.verified) {
      return '错误: 计划尚未通过 verify 校验，不能清除。\n'
          '请先调用 verify 校验通过，输出最终答案后再清除。';
    }

    _currentPlan = null;
    await _savePlan();
    return '计划已清除。';
  }

  Future<String> _verify() async {
    if (_currentPlan == null) return '错误: 当前没有活跃计划';

    final sm = TaskPlanStateMachine(_currentPlan!);
    final result = sm.verify();

    await _savePlan(); // 持久化 verified 状态
    return result.message;
  }



  String _formatProgressWithRemaining(String prefix) {
    if (_currentPlan == null) return '当前没有活跃计划';
    final plan = _currentPlan!;
    final allTasks = plan.tasks;
    final done = allTasks.where((t) => t.status == TaskStatus.done).length;
    final total = allTasks.length;

    final buf = StringBuffer()
      ..writeln('$prefix ($done/$total 已完成)')
      ..writeln();

    // 剩余步骤信息
    final remaining = allTasks
        .where(
          (t) => t.status != TaskStatus.done && t.status != TaskStatus.failed,
        )
        .toList();

    if (remaining.isEmpty) {
      if (_currentPlan!.verified) {
        buf.writeln('✅ 所有步骤已完成且校验通过，现在可以输出最终答案了。');
      } else {
        buf.writeln('⚠️ 所有步骤已完成，请调用 verify 校验通过后再输出最终答案。');
      }
      return buf.toString();
    }

    buf.writeln('📋 剩余步骤 (${remaining.length} 项):');
    for (final task in remaining) {
      final icon = task.status == TaskStatus.inProgress ? '🔄' : '⬜';
      buf.writeln('  $icon ${task.id} ${task.title}');
    }

    final nextInProgress = remaining
        .where((t) => t.status == TaskStatus.inProgress)
        .firstOrNull;
    if (nextInProgress != null) {
      buf.writeln('\n→ 下一步: ${nextInProgress.id} ${nextInProgress.title}');
    } else {
      buf.writeln('\n→ 下一步: 调用 advance 继续');
    }

    final failed = allTasks.where((t) => t.status == TaskStatus.failed).length;
    if (failed > 0) {
      buf.writeln('⚠️ $failed 个任务失败');
    }

    return buf.toString();
  }

  Future<void> _savePlan() async {
    if (_currentPlan == null) return;
    try {
      final fs = getIt<VirtualFileSystem>();
      final json = jsonEncode(_currentPlan!.toJson());
      await fs.mkdir('/scratch');
      await fs.write('/scratch/plan.json', json);
    } catch (e) {
      log.e('TaskPlanTool', '保存任务计划失败: $e');
    }
  }

  Future<void> _loadPlan() async {
    try {
      final fs = getIt<VirtualFileSystem>();
      if (await fs.exists('/scratch/plan.json')) {
        final raw = await fs.read('/scratch/plan.json');
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _currentPlan = TaskPlan.fromJson(data);
        // Auto-save to upgrade old-format plans to the current schema version
        if ((data['schemaVersion'] as int? ?? 0) < taskPlanSchemaVersion) {
          await _savePlan();
        }
      }
    } catch (e) {
      // Log the error for debugging but don't crash — plan is non-critical
      debugPrint('[TaskPlan] 加载计划失败: $e');
    }
  }
}

enum TaskStatus { pending, inProgress, done, failed, blocked }

class TaskNode {
  final String id;
  final String title;
  final String? parentId;
  final List<String> dependsOn;
  TaskStatus status;
  String? note;
  String? blockedReason;

  TaskNode({
    required this.id,
    required this.title,
    this.parentId,
    this.dependsOn = const [],
    this.status = TaskStatus.pending,
    this.note,
    this.blockedReason,
  });

  /// Whether this is a leaf task (no child depends on it as a parent).
  bool isLeaf(List<TaskNode> allTasks) =>
      allTasks.every((t) => t.parentId != id);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (parentId != null) 'parentId': parentId,
    if (dependsOn.isNotEmpty) 'dependsOn': dependsOn,
    'status': status.name,
    if (note != null) 'note': note,
    if (blockedReason != null) 'blockedReason': blockedReason,
  };

  factory TaskNode.fromJson(Map<String, dynamic> json) {
    final deps = json['dependsOn'];
    return TaskNode(
      id: json['id'] as String,
      title: json['title'] as String,
      parentId: json['parentId'] as String?,
      dependsOn: deps is List ? deps.cast<String>() : const [],
      status: TaskStatus.values.byName(json['status'] as String? ?? 'pending'),
      note: json['note'] as String?,
      blockedReason: json['blockedReason'] as String?,
    );
  }
}

/// Current schema version of the TaskPlan JSON format.
/// Bump this when making breaking changes to the plan JSON structure.
/// - v1 (0.8.0): Initial versioned format with dependsOn / blockedReason.
/// - v0 (pre-0.8.0): No schemaVersion field; no dependsOn / blockedReason.
const int taskPlanSchemaVersion = 1;

class TaskPlan {
  final String title;
  final List<TaskNode> tasks;
  bool verified;

  TaskPlan({required this.title, required this.tasks, this.verified = false});

  TaskNode? findTask(String id) {
    try {
      return tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': taskPlanSchemaVersion,
    'title': title,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'verified': verified,
  };

  factory TaskPlan.fromJson(Map<String, dynamic> json) {
    final migrated = _migrateTaskPlan(json);
    return TaskPlan(
      title: migrated['title'] as String,
      tasks: (migrated['tasks'] as List)
          .map((t) => TaskNode.fromJson(t as Map<String, dynamic>))
          .toList(),
      verified: migrated['verified'] as bool? ?? false,
    );
  }

  /// Migrate raw JSON to the current schema version.
  static Map<String, dynamic> _migrateTaskPlan(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 0;
    if (version >= taskPlanSchemaVersion) return json;

    // v0 → v1: ensure each task has dependsOn and blockedReason
    if (version < 1) {
      final rawTasks = json['tasks'] as List?;
      if (rawTasks != null) {
        final migrated = rawTasks.map((t) {
          if (t is! Map<String, dynamic>) return t;
          final m = Map<String, dynamic>.from(t);
          if (!m.containsKey('dependsOn')) m['dependsOn'] = <String>[];
          if (!m.containsKey('blockedReason')) m['blockedReason'] = null;
          return m;
        }).toList();
        json['tasks'] = migrated;
      }
      json['schemaVersion'] = 1;
    }

    return json;
  }
}
