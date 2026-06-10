import 'package:flutter/material.dart';

// ── Message ──

class ChatMessage {
  String text;
  final bool isUser;
  bool isStreaming;

  /// Clean text without tool status markers (image markdown stays for inline rendering)
  String get cleanText => text
      .replaceAll(RegExp(r'🔧.*\n'), '')
      .replaceAll(RegExp(r'✅.*\n'), '')
      .trim();

  /// Timeline steps for AI messages
  List<TimelineStep>? steps;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isStreaming = false,
    this.steps,
  });

  /// Extract image URLs from the message text (from markdown images or plain URLs)
  List<String> get imageUrls {
    final urls = <String>[];
    final mdPattern = RegExp(r'!\[.*?\]\((https?://[^\s)]+)\)');
    for (final match in mdPattern.allMatches(text)) {
      final url = match.group(1);
      if (url != null && url.isNotEmpty) urls.add(url);
    }
    final urlPattern = RegExp(r'(?:图片\s*URL[：:]\s*)(https?://\S+)');
    for (final match in urlPattern.allMatches(text)) {
      final url = match.group(1);
      if (url != null && url.isNotEmpty) urls.add(url);
    }
    return urls;
  }
}

// ── Timeline ──

enum TimelineStepType { thinking, tool }

enum TimelineStepStatus { running, done }

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
