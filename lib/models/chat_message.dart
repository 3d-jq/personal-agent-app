import 'package:flutter/material.dart';

// ── Message ──

class ChatMessage extends ChangeNotifier {
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

  ChatMessage({
    required String text,
    required this.isUser,
    bool isStreaming = false,
    List<TimelineStep>? steps,
    this.speakerId,
    this.mentions = const [],
    this.attachmentPath,
    this.attachmentType,
    this.toolInteractions,
  }) : _text = text,
       _isStreaming = isStreaming,
       _steps = steps;

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

  List<TimelineStep>? get steps => _steps;
  set steps(List<TimelineStep>? value) {
    _steps = value;
    notifyListeners();
  }

  /// 正文已天然干净（工具状态走独立事件），无需再剥离标记。
  String get cleanText => _text;

  Map<String, dynamic> toJson() => {
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

enum TimelineStepType { thinking, tool }

enum TimelineStepStatus { running, done, error }

class TimelineStep {
  String label;
  final TimelineStepType type;
  TimelineStepStatus status;

  /// 步骤详情：思考阶段可放简要描述，工具阶段可放参数摘要或错误信息。
  /// 在 [TimelineView] 中展示在 label 下面单独一行。
  String? detail;

  TimelineStep({
    required this.label,
    required this.type,
    required this.status,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'type': type.name,
    'status': status.name,
    if (detail != null) 'detail': detail,
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
    );
  }
}
