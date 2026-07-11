import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../services/chat_storage.dart';
import '../models/chat_session.dart';
import '../core/service_locator.dart';
import '../services/note_storage.dart';
import 'log_service.dart';

class ExportService {
  ExportService();

  /// 原生分享通道（与 NoteExportService 共用同一 MethodChannel）。
  static const MethodChannel _shareChannel =
      MethodChannel('com.example/share_file');

  /// 调起系统分享面板发送任意文件（日志 .md、文本等）。
  ///
  /// [mimeType] 用 'text/markdown' 分享日志报告，系统选择器可转发到微信/文件管理器等。
  Future<void> shareFileByPath(
      String path, String mimeType, String title) async {
    try {
      await _shareChannel.invokeMethod('shareFile', {
        'path': path,
        'mimeType': mimeType,
        'title': title,
      });
    } catch (e) {
      log.e('ExportService', '分享文件失败: $e');
    }
  }

  Future<String> exportChatAsText(String sessionId) async {
    // 加载完整消息体（full: true 忽略内存窗口）
    final session =
        await getIt<ChatStorage>().loadSession(sessionId, full: true);
    if (session == null || session.messages.isEmpty) return '';

    final buf = StringBuffer();
    buf.writeln('=== DWeis 对话记录 ===');
    buf.writeln('会话: ${session.title}');
    buf.writeln('时间: ${session.updatedAt}');
    buf.writeln('========================\n');

    for (final msg in session.messages) {
      final role = msg.isUser ? '用户' : 'DWeis';
      buf.writeln('[$role]');
      buf.writeln(msg.text);
      buf.writeln('');
    }

    return buf.toString();
  }

  Future<String> exportAllChatsAsJson() async {
    final metas = await getIt<ChatStorage>().loadAll();
    final full = <ChatSession>[];
    for (final m in metas) {
      final s =
          await getIt<ChatStorage>().loadSession(m.id, full: true);
      if (s != null) full.add(s);
    }
    final data = full.map((s) => s.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<String> exportNotesAsText() async {
    final notes = await getIt<NoteStorage>().loadAll();
    final buf = StringBuffer();
    buf.writeln('=== DWeis 笔记导出 ===');
    buf.writeln('导出时间: ${DateTime.now()}');
    buf.writeln('共 ${notes.length} 条笔记\n');

    for (final note in notes) {
      buf.writeln('--- ${note.title} ---');
      buf.writeln('创建: ${note.createdAt}');
      buf.writeln('更新: ${note.updatedAt}');
      buf.writeln(note.content);
      buf.writeln('');
    }

    return buf.toString();
  }

  Future<String> exportNotesAsJson() async {
    final notes = await getIt<NoteStorage>().loadAll();
    final data = notes.map((n) => n.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> shareText(String text, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(text);
    try {
      await const MethodChannel('com.example/share_file').invokeMethod(
        'shareFile',
        {'path': file.path, 'mimeType': 'text/plain', 'title': 'DWeis 导出'},
      );
    } catch (e) {
      log.e('ExportService', '分享文件失败: $e');
    }
  }
}
