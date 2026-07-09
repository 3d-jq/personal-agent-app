import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../tools/task_plan_tool.dart';

// ── Message ──

class ChatMessage extends ChangeNotifier {
  final String id;
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
    bool isStreaming = false,
    List<TimelineStep>? steps,
    this.speakerId,
    this.mentions = const [],
    this.attachmentPath,
    this.attachmentType,
    this.toolInteractions,
    TaskPlan? plan,
  }) : id = id ?? const Uuid().v4(),
       _text = text,
       _isStreaming = isStreaming,
       _steps = steps,
       _plan = plan;

  String get text => _text;
  set text(String value) {
    if (_text != value) {
      _text = value;
      notifyListeners();
    }
  }

  bool get isStreaming => _isStreaming;
  set isStreaming(bool value) {
    if (_isStreaming != value) {
      _isStreaming = value;
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

  Map<String, dynamic> toJson() => {
    'id': id,
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
