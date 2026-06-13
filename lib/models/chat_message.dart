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

  String? _cleanTextCache;

  String get text => _text;
  set text(String value) {
    if (_text != value) {
      _text = value;
      _cleanTextCache = null;
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

  /// Clean text without tool status markers (image markdown stays for inline rendering)
  String get cleanText {
    return _cleanTextCache ??= _text
        .replaceAll(RegExp(r'🔧.*\n'), '')
        .replaceAll(RegExp(r'✅.*\n'), '')
        .trim();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Extract image URLs from the message text (from markdown images or plain URLs)
  List<String> get imageUrls {
    final urls = <String>[];
    final mdPattern = RegExp(r'!\[.*?\]\((https?://[^\s)]+)\)');
    for (final match in mdPattern.allMatches(_text)) {
      final url = match.group(1);
      if (url != null && url.isNotEmpty) urls.add(url);
    }
    final urlPattern = RegExp(r'(?:图片\s*URL[：:]\s*)(https?://\S+)');
    for (final match in urlPattern.allMatches(_text)) {
      final url = match.group(1);
      if (url != null && url.isNotEmpty) urls.add(url);
    }
    return urls;
  }
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
