import 'package:flutter/material.dart';

// ── Message ──

class ChatMessage extends ChangeNotifier {
  String _text;
  final bool isUser;
  bool _isStreaming;
  List<TimelineStep>? _steps;

  ChatMessage({
    required String text,
    required this.isUser,
    bool isStreaming = false,
    List<TimelineStep>? steps,
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
