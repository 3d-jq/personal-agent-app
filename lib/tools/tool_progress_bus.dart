import 'dart:async';

/// 单个工具的执行进度事件。
class ToolProgressEvent {
  final String toolName;

  /// 0.0 .. 1.0
  final double progress;
  final String message;
  final int priority;
  final int level;

  const ToolProgressEvent({
    required this.toolName,
    required this.progress,
    this.message = '',
    this.priority = 0,
    this.level = 0,
  });

  @override
  String toString() =>
      'ToolProgressEvent($toolName, ${(progress * 100).round()}%, $message)';
}

/// 工具级实时进度总线（比 [AgentStatus] 更细）。
///
/// 借鉴 Operit `ToolProgressBus`：单例广播 [ToolProgressEvent]，后到的低优先级
/// 事件不会覆盖「进行中 / 更高优先级」的事件。UI 可订阅 [stream] 展示细粒度工具进度，
/// 也可用 [summaryToolName] 进度做整体进度条。
class ToolProgressBus {
  ToolProgressBus._();
  static final ToolProgressBus instance = ToolProgressBus._();

  /// 整体进度汇总专用工具名（最高优先级）。
  static const String summaryToolName = '__SUMMARY__';

  final StreamController<ToolProgressEvent> _controller =
      StreamController<ToolProgressEvent>.broadcast();
  ToolProgressEvent? _last;

  Stream<ToolProgressEvent> get stream => _controller.stream;
  ToolProgressEvent? get current => _last;

  int _priorityForTool(String toolName) {
    switch (toolName) {
      case summaryToolName:
        return 1000;
      case 'delegate_task':
        return 100;
      case 'web_fetch':
        return 10;
      case 'fs_write':
      case 'fs_mkdir':
      case 'fs_rm':
        return 5;
      default:
        return 0;
    }
  }

  void update(String toolName, double progress,
      {String message = '', int priority = 0, int level = 0}) {
    updateDetailed(
      toolName,
      progress,
      message: message,
      priority: priority,
      level: level,
    );
  }

  void updateDetailed(
    String toolName,
    double progress, {
    String message = '',
    int priority = 0,
    int level = 0,
  }) {
    final next = ToolProgressEvent(
      toolName: toolName,
      progress: progress.clamp(0.0, 1.0),
      message: message,
      priority: priority == 0 ? _priorityForTool(toolName) : priority,
      level: level,
    );

    final current = _last;
    final shouldReplace = current == null ||
        current.toolName == next.toolName ||
        current.progress >= 1.0 ||
        next.priority > current.priority ||
        (next.priority == current.priority && next.level >= current.level);

    if (shouldReplace) {
      _last = next;
      _controller.add(next);
    }
  }

  /// 复位（工具批次结束后调用）。广播一个 summary 完成事件，提示订阅者收起进度。
  void clear() {
    _last = null;
    _controller.add(const ToolProgressEvent(
      toolName: summaryToolName,
      progress: 1.0,
      message: '',
    ));
  }
}
