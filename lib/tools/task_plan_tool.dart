import 'dart:convert';
import 'base_tool.dart';
import '../services/virtual_fs.dart';

/// 任务计划工具：帮助大模型在执行复杂多步任务时保持进度。
///
/// 支持：
/// - 创建计划（含子任务树）
/// - 更新任务状态（pending/in_progress/done/failed/blocked）
/// - 任务持久化到虚拟文件系统
/// - 查看当前进度摘要
class TaskPlanTool extends AgentTool {
  /// 当前活跃计划
  _TaskPlan? _plan;

  /// 最后一次操作的状态文本（供 UI 面板读取）
  String? lastStatusText;

  @override
  String get name => 'task_plan';

  @override
  String get description =>
      '管理当前任务的执行计划。当你要完成一个多步骤的复杂任务时，'
      '先创建计划列出所有步骤，然后逐步更新完成状态。'
      '支持子任务：一个步骤可以拆分为多个子步骤。'
      '计划会自动保存到虚拟文件系统 /scratch/plan.json，跨轮次保持进度。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['create', 'update', 'status', 'clear'],
            'description': 'create: 创建新计划; update: 更新任务状态; status: 查看进度; clear: 清除计划',
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
                'id': {'type': 'string', 'description': '任务ID，如 T1, T2, T1.1'},
                'title': {'type': 'string', 'description': '任务描述'},
                'parent': {'type': 'string', 'description': '父任务ID（可选，用于子任务）'},
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

    // 尝试从虚拟文件系统恢复计划
    if (_plan == null) {
      await _loadPlan();
    }

    switch (action) {
      case 'create':
        final result = _create(args);
        lastStatusText = result;
        return result;
      case 'update':
        final result = _update(args);
        lastStatusText = result;
        return result;
      case 'status':
        final result = _status();
        lastStatusText = result;
        return result;
      case 'clear':
        _plan = null;
        await _savePlan();
        return '计划已清除。';
      default:
        return '错误: action 必须为 create / update / status / clear 之一';
    }
  }

  String _create(Map<String, dynamic> args) {
    final title = (args['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return '错误: 创建计划需要提供 title';

    final rawTasks = (args['tasks'] as List?) ?? [];
    if (rawTasks.isEmpty) return '错误: 创建计划需要提供 tasks 列表';

    final tasks = <TaskNode>[];
    for (final raw in rawTasks) {
      if (raw is! Map) continue;
      final id = raw['id'] as String? ?? '';
      final title = raw['title'] as String? ?? '';
      final parent = raw['parent'] as String?;
      if (id.isEmpty || title.isEmpty) continue;
      tasks.add(TaskNode(id: id, title: title, parentId: parent));
    }

    if (tasks.isEmpty) return '错误: 没有有效的任务项';

    _plan = _TaskPlan(title: title, tasks: tasks);
    _savePlan();
    return _formatProgress('计划已创建');
  }

  String _update(Map<String, dynamic> args) {
    if (_plan == null) return '当前没有活跃计划，请先用 create 创建';

    final taskId = args['task_id'] as String?;
    if (taskId == null || taskId.isEmpty) return '错误: update 需要提供 task_id';

    final task = _plan!.findTask(taskId);
    if (task == null) return '错误: 找不到任务 $taskId';

    final newStatus = args['status'] as String?;
    if (newStatus == null) return '错误: update 需要提供 status';

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

    // 自动更新父任务状态
    _autoUpdateParent(task);

    _savePlan();
    return _formatProgress('任务 $taskId 已更新为 $newStatus');
  }

  String _status() {
    if (_plan == null) return '当前没有活跃计划';
    return _formatProgress('当前进度');
  }

  void _autoUpdateParent(TaskNode task) {
    if (task.parentId == null || _plan == null) return;
    final parent = _plan!.findTask(task.parentId!);
    if (parent == null) return;

    final children = _plan!.tasks.where((t) => t.parentId == parent.id).toList();
    if (children.isEmpty) return;

    // 如果所有子任务都 done，父任务也 done
    if (children.every((c) => c.status == TaskStatus.done)) {
      parent.status = TaskStatus.done;
    }
    // 如果有任何子任务 in_progress，父任务也 in_progress
    else if (children.any((c) => c.status == TaskStatus.inProgress)) {
      parent.status = TaskStatus.inProgress;
    }
    // 如果有任何子任务 failed，父任务也 failed
    else if (children.any((c) => c.status == TaskStatus.failed)) {
      parent.status = TaskStatus.failed;
    }
  }

  String _formatProgress(String header) {
    if (_plan == null) return '当前没有活跃计划';
    final plan = _plan!;

    final allTasks = plan.tasks;
    final done = allTasks.where((t) => t.status == TaskStatus.done).length;
    final total = allTasks.length;
    final rootTasks = allTasks.where((t) => t.parentId == null).toList();

    final buf = StringBuffer()
      ..writeln('$header: ${plan.title} ($done/$total 已完成)')
      ..writeln();

    for (final task in rootTasks) {
      _printTask(buf, task, allTasks, 0);
    }

    // 给出下一步建议
    final next = allTasks.firstWhere(
      (t) => t.status == TaskStatus.pending || t.status == TaskStatus.inProgress,
      orElse: () => allTasks.first,
    );
    if (done < total) {
      buf.writeln('\n→ 下一步: ${next.id} ${next.title}');
    } else {
      buf.writeln('\n🎉 所有任务已完成！');
    }

    return buf.toString();
  }

  void _printTask(StringBuffer buf, TaskNode task, List<TaskNode> allTasks, int depth) {
    final indent = '  ' * depth;
    final icon = switch (task.status) {
      TaskStatus.pending => '⬜',
      TaskStatus.inProgress => '🔄',
      TaskStatus.done => '✅',
      TaskStatus.failed => '❌',
      TaskStatus.blocked => '🚫',
    };
    final note = task.note != null ? ' (${task.note})' : '';
    buf.writeln('$indent${task.id}. $icon ${task.title}$note');

    // 打印子任务
    final children = allTasks.where((t) => t.parentId == task.id).toList();
    for (final child in children) {
      _printTask(buf, child, allTasks, depth + 1);
    }
  }

  Future<void> _savePlan() async {
    if (_plan == null) return;
    try {
      final fs = VirtualFileSystem();
      final json = jsonEncode(_plan!.toJson());
      await fs.mkdir('/scratch');
      await fs.write('/scratch/plan.json', json);
    } catch (_) {}
  }

  Future<void> _loadPlan() async {
    try {
      final fs = VirtualFileSystem();
      if (await fs.exists('/scratch/plan.json')) {
        final json = await fs.read('/scratch/plan.json');
        final data = jsonDecode(json) as Map<String, dynamic>;
        _plan = _TaskPlan.fromJson(data);
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

class _TaskPlan {
  final String title;
  final List<TaskNode> tasks;

  _TaskPlan({required this.title, required this.tasks});

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
      };

  factory _TaskPlan.fromJson(Map<String, dynamic> json) => _TaskPlan(
        title: json['title'] as String,
        tasks: (json['tasks'] as List)
            .map((t) => TaskNode.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
