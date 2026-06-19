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

  ChatMessage({
    required String text,
    required this.isUser,
    bool isStreaming = false,
    List<TimelineStep>? steps,
    this.speakerId,
    this.mentions = const [],
  })  : _text = text,
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
}

// ── Timeline ──

enum TimelineStepType { thinking, tool }

enum TimelineStepStatus { running, done, error }

class TimelineStep {
  String label;
  final TimelineStepType type;
  TimelineStepStatus status;

  TimelineStep({
    required this.label,
    required this.type,
    required this.status,
  });
}
