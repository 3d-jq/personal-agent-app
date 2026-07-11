import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/text_sanitizer.dart';
import '../tools/task_plan_tool.dart';

// ── Message ──

class ChatMessage extends ChangeNotifier {
  final String id;
  /// 全局序号（插入顺序）。用于消息分页表的稳定排序与增量 upsert，
  /// 不依赖内存中列表的下标，避免窗口化后重排导致顺序错乱。
  int seq;
  String _text;
  final bool isUser;
  bool _isStreaming;
  List<TimelineStep>? _steps;

  /// Agent 群聊场景下：发言者的 Agent id。用户发言时为 null。
  /// 单聊场景下保持 null，向后兼容。
  final String? speakerId;

  /// Agent 群聊场景下：被 @ 提及的 Agent name 列表（精确匹配）。
  /// 单聊场景下保持空列表。
  final List<String> mentions;

  /// 用户附件的本地文件路径（图片/文档），用于在气泡中渲染预览。
  String? attachmentPath;

  /// 附件类型：'image' 或 'document'。
  String? attachmentType;

  /// 工具调用交互记录，用于跨轮次保持上下文。
  /// 每个元素代表一轮工具调用：{toolCalls: [...], toolResults: [...]}
  List<Map<String, dynamic>>? toolInteractions;

  /// 任务计划（task_plan 工具触发时），渲染在 AI 气泡内的 plan 卡片。
  /// 不持久化：会话重载后不恢复（与原输入框上方悬浮面板行为一致）。
  TaskPlan? _plan;

  ChatMessage({
    String? id,
    required String text,
    required this.isUser,
    this.seq = -1,
    bool isStreaming = false,
    List<TimelineStep>? steps,
    this.speakerId,
    this.mentions = const [],
    this.attachmentPath,
    this.attachmentType,
    this.toolInteractions,
    TaskPlan? plan,
  }) : id = id ?? const Uuid().v4(),
       _text = sanitizeUtf16(text),
       _isStreaming = isStreaming,
       _steps = steps,
       _plan = plan;

  String get text => _text;
  /// 流式渲染节流：把高频 token 写入合并为 ≤5Hz 的 UI 重建（与 Operit
  /// `RENDER_INTERVAL_MS=200` 批处理层等价），避免每帧重解析活跃块导致卡顿。
  /// 逻辑文本 `_text` 始终即时更新（存取/复制正确），仅 `notifyListeners` 被节流：
  /// 首包 leading-edge 即时上屏（慢速流不延迟），窗口内合并、200ms 边界 trailing flush。
  Timer? _textThrottleTimer;
  bool _textThrottleTrailing = false;

  set text(String value) {
    final cleaned = sanitizeUtf16(value);
    if (_text == cleaned) return;
    _text = cleaned;
    _scheduleTextNotify();
  }

  void _scheduleTextNotify() {
    if (_textThrottleTimer == null && !_textThrottleTrailing) {
      notifyListeners();
      _textThrottleTimer =
          Timer(const Duration(milliseconds: 200), _flushTextNotify);
    } else {
      _textThrottleTrailing = true;
    }
  }

  void _flushTextNotify() {
    _textThrottleTimer = null;
    if (_textThrottleTrailing) {
      _textThrottleTrailing = false;
      notifyListeners();
    }
  }

  void _cancelTextThrottle() {
    _textThrottleTimer?.cancel();
    _textThrottleTimer = null;
    _textThrottleTrailing = false;
  }

  bool get isStreaming => _isStreaming;
  set isStreaming(bool value) {
    if (_isStreaming != value) {
      _isStreaming = value;
      if (!value) _cancelTextThrottle(); // 流结束立即刷新最终文本，避免残留定时器
      notifyListeners();
    }
  }

  TaskPlan? get plan => _plan;
  set plan(TaskPlan? value) {
    if (_plan != value) {
      _plan = value;
      notifyListeners();
    }
  }

  /// 标记该消息为「错误气泡」，UI 据此渲染为内联报错卡而非普通正文。
  bool _isError = false;
  bool get isError => _isError;
  set isError(bool value) {
    if (_isError != value) {
      _isError = value;
      notifyListeners();
    }
  }

  List<TimelineStep>? get steps => _steps;
  set steps(List<TimelineStep>? value) {
    _steps = value;
    notifyListeners();
  }

  /// 正文已天然干净（工具状态走独立事件），无需再剥离标记。
  String get cleanText => _text;

  @override
  void dispose() {
    _cancelTextThrottle();
    super.dispose();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'seq': seq,
    'text': _text,
    'isUser': isUser,
    'isStreaming': _isStreaming,
    'steps': _steps?.map((s) => s.toJson()).toList(),
    'speakerId': speakerId,
    'mentions': mentions,
    if (attachmentPath != null) 'attachmentPath': attachmentPath,
    if (attachmentType != null) 'attachmentType': attachmentType,
    if (toolInteractions != null) 'toolInteractions': toolInteractions,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      seq: json['seq'] as int? ?? -1,
      isStreaming: json['isStreaming'] as bool? ?? false,
      steps: (json['steps'] as List?)
          ?.map((s) => TimelineStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      speakerId: json['speakerId'] as String?,
      mentions: (json['mentions'] as List?)?.cast<String>() ?? const [],
      attachmentPath: json['attachmentPath'] as String?,
      attachmentType: json['attachmentType'] as String?,
      toolInteractions: (json['toolInteractions'] as List?)
          ?.cast<Map<String, dynamic>>(),
    );
  }
}

// ── Timeline ──

enum TimelineStepType { thinking, tool, compress }

enum TimelineStepStatus { running, done, error }

class TimelineStep {
  String label;
  final TimelineStepType type;
  TimelineStepStatus status;

  /// 步骤详情：思考阶段可放简要描述，工具阶段可放参数摘要或错误信息。
  /// 在 [TimelineView] 中展示在 label 下面单独一行。
  String? detail;

  /// 工具调用唯一 id（与模型 tool_call_id 对应）。
  /// 并发完成时用于精确匹配步骤，避免同名工具互相错配。
  final String? toolId;

  TimelineStep({
    required this.label,
    required this.type,
    required this.status,
    this.detail,
    this.toolId,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'type': type.name,
    'status': status.name,
    if (detail != null) 'detail': detail,
    if (toolId != null) 'toolId': toolId,
  };

  factory TimelineStep.fromJson(Map<String, dynamic> json) {
    return TimelineStep(
      label: json['label'] as String? ?? '',
      type: TimelineStepType.values.byName(
        json['type'] as String? ?? 'thinking',
      ),
      status: TimelineStepStatus.values.byName(
        json['status'] as String? ?? 'running',
      ),
      detail: json['detail'] as String?,
      toolId: json['toolId'] as String?,
    );
  }
}
