import 'base_tool.dart';

/// 任务计划工具：帮助大模型在执行复杂多步任务时保持进度，防止遗忘步骤。
///
/// 大模型可在任务开始时创建计划，每完成一步更新状态，
/// 工具返回当前进度摘要，帮助模型回顾全局并决定下一步行动。
class TaskPlanTool extends AgentTool {
  /// 当前活跃计划（同一时刻只维护一个）
  final List<_TaskItem> _tasks = [];
  String? _planTitle;

  /// 重置计划状态（新对话开始时调用）
  void reset() {
    _tasks.clear();
    _planTitle = null;
  }

  @override
  String get name => 'task_plan';

  @override
  String get description =>
      '管理当前任务的执行计划。当你要完成一个多步骤的复杂任务时，'
      '先创建计划列出所有步骤，然后逐步更新完成状态。'
      '每次调用会返回当前进度摘要，帮助你回顾全局、不遗漏任何步骤。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['create', 'update', 'status'],
            'description':
                'create: 创建新计划（覆盖旧的）；update: 更新某个任务的状态；status: 查看当前进度',
          },
          'title': {
            'type': 'string',
            'description': '计划标题（仅 create 时必填）',
          },
          'tasks': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '任务列表（仅 create 时使用），每项为一个步骤的简要描述',
          },
          'task_index': {
            'type': 'integer',
            'description': '任务序号（从 1 开始，仅 update 时必填）',
          },
          'status': {
            'type': 'string',
            'enum': ['in_progress', 'done', 'cancelled'],
            'description': '新状态（仅 update 时使用）',
          },
        },
        'required': ['action'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String? ?? '';

    switch (action) {
      case 'create':
        return _create(args);
      case 'update':
        return _update(args);
      case 'status':
        return _status();
      default:
        return '错误: action 必须为 create / update / status 之一';
    }
  }

  String _create(Map<String, dynamic> args) {
    final title = (args['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return '错误: 创建计划需要提供 title';

    final rawTasks = (args['tasks'] as List?)?.cast<String>() ?? [];
    if (rawTasks.isEmpty) return '错误: 创建计划需要提供 tasks 列表（至少一个步骤）';

    _planTitle = title;
    _tasks
      ..clear()
      ..addAll(rawTasks.map((t) => _TaskItem(description: t.trim())));

    return _formatProgress('计划已创建');
  }

  String _update(Map<String, dynamic> args) {
    if (_tasks.isEmpty) return '当前没有活跃计划，请先用 create 创建';

    final raw = args['task_index'];
    final index = raw is int ? raw : (raw is num ? raw.toInt() : null);
    if (index == null || index < 1 || index > _tasks.length) {
      return '错误: task_index 无效（有效范围: 1~${_tasks.length}）';
    }

    final newStatus = args['status'] as String?;
    if (newStatus == null) return '错误: update 需要提供 status';

    final task = _tasks[index - 1];
    switch (newStatus) {
      case 'in_progress':
        task.status = _TaskStatus.inProgress;
      case 'done':
        task.status = _TaskStatus.done;
      case 'cancelled':
        task.status = _TaskStatus.cancelled;
      default:
        return '错误: status 必须为 in_progress / done / cancelled 之一';
    }

    return _formatProgress('任务 #$index 已更新为 $newStatus');
  }

  String _status() {
    if (_tasks.isEmpty) return '当前没有活跃计划';
    return _formatProgress('当前进度');
  }

  String _formatProgress(String header) {
    final done = _tasks.where((t) => t.status == _TaskStatus.done).length;
    final total = _tasks.length;
    final buf = StringBuffer()
      ..writeln('$header: $_planTitle ($done/$total 已完成)')
      ..writeln();

    for (var i = 0; i < _tasks.length; i++) {
      final t = _tasks[i];
      final icon = switch (t.status) {
        _TaskStatus.pending => '⬜',
        _TaskStatus.inProgress => '🔄',
        _TaskStatus.done => '✅',
        _TaskStatus.cancelled => '⛔',
      };
      buf.writeln('${i + 1}. $icon ${t.description}');
    }

    // 给出下一步建议
    final next = _tasks.indexWhere((t) => t.status == _TaskStatus.pending);
    if (next >= 0) {
      buf.writeln('\n→ 下一步: #${next + 1} ${_tasks[next].description}');
    } else if (done == total) {
      buf.writeln('\n🎉 所有任务已完成！');
    }

    return buf.toString();
  }
}

enum _TaskStatus { pending, inProgress, done, cancelled }

class _TaskItem {
  final String description;
  _TaskStatus status = _TaskStatus.pending;
  _TaskItem({required this.description});
}
