import 'dart:convert';
import 'base_tool.dart';
import 'task_plan_tool.g.dart';
import '../core/service_locator.dart';
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
  static TaskPlan? _currentPlan;
  static TaskPlan? get currentPlan => _currentPlan;

  static String? lastStatusText;

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
          'title': {
            'type': 'string',
            'description': '计划标题（仅 create 时必填）',
          },
          'tasks': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'id': {
                  'type': 'string',
                  'description': '任务ID，如 T1, T2, T1.1',
                },
                'title': {'type': 'string', 'description': '任务描述'},
                'parent': {
                  'type': 'string',
                  'description': '父任务ID（可选，用于子任务）',
                },
              },
              'required': ['id', 'title'],
            },
            'description': '任务列表（仅 create 时使用），支持通过 parent 字段构建子任务树',
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
          'note': {
            'type': 'string',
            'description': '状态更新备注（可选）',
          },
        },
        'required': ['action'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
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
        final result = _verify();
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
      if (id.isEmpty || taskTitle.isEmpty) continue;
      if (tasks.any((t) => t.id == id)) {
        return '错误: 任务ID $id 重复，请使用唯一ID';
      }
      tasks.add(TaskNode(id: id, title: taskTitle, parentId: parent));
    }

    if (tasks.isEmpty) return '错误: 没有有效的任务项';

    // create 时自动将第一个可执行（叶子）任务设为 in_progress，减少一轮空交互
    final leafTasks = tasks.where((t) => tasks.every((other) => other.parentId != t.id)).toList();
    if (leafTasks.isNotEmpty) {
      leafTasks.first.status = TaskStatus.inProgress;
    }

    _currentPlan = TaskPlan(title: title, tasks: tasks, verified: false);
    await _savePlan();
    return _formatProgressWithRemaining('计划已创建');
  }

  Future<String> _update(Map<String, dynamic> args) async {
    if (_currentPlan == null) return '当前没有活跃计划，请先用 create 创建';

    final taskId = args['task_id'] as String?;
    if (taskId == null || taskId.isEmpty) return '错误: update 需要提供 task_id';

    final task = _currentPlan!.findTask(taskId);
    if (task == null) return '错误: 找不到任务 $taskId';

    final newStatus = args['status'] as String?;
    if (newStatus == null) return '错误: update 需要提供 status';

    if ((task.status == TaskStatus.done || task.status == TaskStatus.failed) &&
        newStatus != task.status.name) {
      return '错误: 任务 $taskId 已${task.status == TaskStatus.done ? '完成' : '失败'}，不可回退';
    }

    final note = args['note'] as String?;

    switch (newStatus) {
      case 'pending':
        task.status = TaskStatus.pending;
      case 'in_progress':
        task.status = TaskStatus.inProgress;
      case 'done':
        task.status = TaskStatus.done;
      case 'failed':
        task.status = TaskStatus.failed;
      case 'blocked':
        task.status = TaskStatus.blocked;
      default:
        return '错误: status 必须为 pending / in_progress / done / failed / blocked 之一';
    }

    if (note != null) task.note = note;

    _autoUpdateParent(task);
    _currentPlan!.verified = false;

    await _savePlan();
    return _formatProgressWithRemaining('任务 $taskId 已更新为 $newStatus');
  }

  Future<String> _advance() async {
    if (_currentPlan == null) {
      return '错误: 当前没有活跃计划，请先用 create 创建';
    }

    final allTasks = _currentPlan!.tasks;

    // 1. 找当前 in_progress 的任务
    final current = allTasks
        .where((t) => t.status == TaskStatus.inProgress)
        .firstOrNull;

    if (current == null) {
      return '错误: 当前没有正在进行的任务。\n'
          '请用 update 手动将某个任务设为 in_progress，然后再调用 advance。';
    }

    // 2. 标记当前任务为 done
    current.status = TaskStatus.done;
    _autoUpdateParent(current);

    // 3. 找下一个 pending 的叶子任务，自动设为 in_progress
    TaskNode? next;
    for (final task in allTasks) {
      if (task.status != TaskStatus.pending) continue;
      final children = allTasks.where((t) => t.parentId == task.id).toList();
      if (children.isEmpty || children.every((c) => c.status == TaskStatus.done)) {
        next = task;
        break;
      }
    }

    if (next != null) {
      next.status = TaskStatus.inProgress;
    }

    _currentPlan!.verified = false;
    await _savePlan();

    final allDone = _currentPlan!.tasks
        .where((t) =>
            t.status != TaskStatus.done && t.status != TaskStatus.failed)
        .isEmpty;
    if (allDone) {
      return '✅ 已完成 ${current.id} "${current.title}"\n'
          '⚠️ 所有步骤已完成，请调用 verify 校验通过后再输出最终答案。';
    }

    return _formatProgressWithRemaining(
        '✅ 已完成 ${current.id} "${current.title}"');
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

  String _verify() {
    if (_currentPlan == null) return '错误: 当前没有活跃计划';

    final notDone = _currentPlan!.tasks
        .where((t) =>
            t.status != TaskStatus.done && t.status != TaskStatus.failed)
        .toList();

    if (notDone.isNotEmpty) {
      _currentPlan!.verified = false;
      final ids = notDone.map((t) => t.id).join(', ');
      return '❌ 校验失败！还有未完成的任务: $ids\n'
          '请继续推进，不要提前输出最终答案。';
    }

    _currentPlan!.verified = true;
    return '✅ 校验通过！所有任务已完成，现在可以输出最终答案了。';
  }

  void _autoUpdateParent(TaskNode task) {
    if (task.parentId == null || _currentPlan == null) return;
    final parent = _currentPlan!.findTask(task.parentId!);
    if (parent == null) return;

    final children =
        _currentPlan!.tasks.where((t) => t.parentId == parent.id).toList();
    if (children.isEmpty) return;

    if (children.every((c) => c.status == TaskStatus.done)) {
      parent.status = TaskStatus.done;
    } else if (children.any((c) => c.status == TaskStatus.inProgress)) {
      parent.status = TaskStatus.inProgress;
    } else if (children.any((c) => c.status == TaskStatus.failed)) {
      parent.status = TaskStatus.failed;
    }
  }

  String _formatProgressWithRemaining(String prefix) {
    if (_currentPlan == null) return '当前没有活跃计划';
    final plan = _currentPlan!;
    final allTasks = plan.tasks;
    final done = allTasks.where((t) => t.status == TaskStatus.done).length;
    final total = allTasks.length;

    final buf = StringBuffer()
      ..writeln('$prefix (${done}/${total} 已完成)')
      ..writeln();

    // 剩余步骤信息
    final remaining = allTasks
        .where(
            (t) => t.status != TaskStatus.done && t.status != TaskStatus.failed)
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

    final nextInProgress =
        remaining.where((t) => t.status == TaskStatus.inProgress).firstOrNull;
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
    } catch (_) {}
  }

  Future<void> _loadPlan() async {
    try {
      final fs = getIt<VirtualFileSystem>();
      if (await fs.exists('/scratch/plan.json')) {
        final json = await fs.read('/scratch/plan.json');
        final data = jsonDecode(json) as Map<String, dynamic>;
        _currentPlan = TaskPlan.fromJson(data);
      }
    } catch (_) {}
  }
}

enum TaskStatus { pending, inProgress, done, failed, blocked }

class TaskNode {
  final String id;
  final String title;
  final String? parentId;
  TaskStatus status;
  String? note;

  TaskNode({
    required this.id,
    required this.title,
    this.parentId,
    this.status = TaskStatus.pending,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (parentId != null) 'parentId': parentId,
        'status': status.name,
        if (note != null) 'note': note,
      };

  factory TaskNode.fromJson(Map<String, dynamic> json) => TaskNode(
        id: json['id'] as String,
        title: json['title'] as String,
        parentId: json['parentId'] as String?,
        status: TaskStatus.values.byName(json['status'] as String? ?? 'pending'),
        note: json['note'] as String?,
      );
}

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
        'title': title,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'verified': verified,
      };

  factory TaskPlan.fromJson(Map<String, dynamic> json) => TaskPlan(
        title: json['title'] as String,
        tasks: (json['tasks'] as List)
            .map((t) => TaskNode.fromJson(t as Map<String, dynamic>))
            .toList(),
        verified: json['verified'] as bool? ?? false,
      );
}
