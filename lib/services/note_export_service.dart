import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';

class NoteExportService {
  static const _channel = MethodChannel('com.example/share_file');

  static Future<void> exportToWord(Note note) async {
    final html = _buildHtml(note);

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        '笔记_${note.title}_${DateTime.now().millisecondsSinceEpoch}.html';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(html);

    try {
      await _channel.invokeMethod('shareFile', {
        'path': file.path,
        'mimeType': 'text/html',
        'title': note.title,
      });
    } catch (_) {
      // fallback: just save the file
    }
  }

  static String _buildHtml(Note note) {
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="zh-CN">');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<title>${_escapeHtml(note.title)}</title>');
    buffer.writeln('<style>');
    buffer.writeln(
      'body { font-family: "Microsoft YaHei", "微软雅黑", sans-serif; max-width: 800px; margin: 0 auto; padding: 40px; color: #333; line-height: 1.8; }',
    );
    buffer.writeln(
      'h1 { font-size: 24px; border-bottom: 2px solid #0F7B6C; padding-bottom: 10px; color: #37352F; }',
    );
    buffer.writeln('h2 { font-size: 20px; color: #37352F; margin-top: 24px; }');
    buffer.writeln('h3 { font-size: 18px; color: #37352F; }');
    buffer.writeln('p { margin: 8px 0; }');
    buffer.writeln(
      'code { background: #f5f5f5; padding: 2px 6px; border-radius: 4px; font-family: monospace; }',
    );
    buffer.writeln(
      'pre { background: #1e1e1e; color: #d4d4d4; padding: 16px; border-radius: 8px; overflow-x: auto; }',
    );
    buffer.writeln(
      'pre code { background: none; padding: 0; color: inherit; }',
    );
    buffer.writeln(
      'blockquote { border-left: 4px solid #0F7B6C; padding-left: 16px; color: #666; margin: 16px 0; }',
    );
    buffer.writeln('ul, ol { padding-left: 24px; }');
    buffer.writeln('li { margin: 4px 0; }');
    buffer.writeln(
      '.date { color: #999; font-size: 12px; margin-bottom: 20px; }',
    );
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');

    buffer.writeln('<h1>${_escapeHtml(note.title)}</h1>');

    final dateStr =
        '${note.createdAt.year}/${note.createdAt.month.toString().padLeft(2, '0')}/${note.createdAt.day.toString().padLeft(2, '0')} '
        '${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}';
    buffer.writeln('<div class="date">创建于 $dateStr</div>');

    final lines = note.content.split('\n');
    for (final line in lines) {
      buffer.writeln(_convertLine(line));
    }

    buffer.writeln('</body>');
    buffer.writeln('</html>');
    return buffer.toString();
  }

  static String _convertLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return '<br>';

    if (trimmed.startsWith('### '))
      return '<h3>${_escapeHtml(trimmed.substring(4))}</h3>';
    if (trimmed.startsWith('## '))
      return '<h2>${_escapeHtml(trimmed.substring(3))}</h2>';
    if (trimmed.startsWith('# '))
      return '<h1>${_escapeHtml(trimmed.substring(2))}</h1>';

    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      return '<li>${_escapeHtml(trimmed.substring(2))}</li>';
    }

    if (trimmed.startsWith('> ')) {
      return '<blockquote>${_escapeHtml(trimmed.substring(2))}</blockquote>';
    }

    if (trimmed.startsWith('```'))
      return trimmed.contains('```') ? '<pre><code>' : '</code></pre>';

    final imgMatch = RegExp(
      r'!\[.*?\]\((file://[^\s)]+)\)',
    ).firstMatch(trimmed);
    if (imgMatch != null) {
      final filePath = imgMatch.group(1)!.replaceFirst('file://', '');
      return '<p><img src="file:///$filePath" style="max-width:100%;border-radius:8px;margin:8px 0;"></p>';
    }

    var text = _escapeHtml(trimmed);
    text = text.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (m) => '<strong>${m.group(1)}</strong>',
    );
    text = text.replaceAllMapped(
      RegExp(r'\*(.+?)\*'),
      (m) => '<em>${m.group(1)}</em>',
    );
    text = text.replaceAllMapped(
      RegExp(r'`(.+?)`'),
      (m) => '<code>${m.group(1)}</code>',
    );

    return '<p>$text</p>';
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
