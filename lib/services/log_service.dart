import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 全局日志服务
///
/// 支持文件日志和控制台日志，可在设置中开关
class LogService {
  static final LogService _instance = LogService._();
  factory LogService() => _instance;
  LogService._();

  bool _enabled = false;
  IOSink? _sink;
  File? _logFile;

  bool get enabled => _enabled;

  /// 启用/禁用日志
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (value) {
      await _initFile();
    } else {
      await _close();
    }
  }

  Future<void> _initFile() async {
    if (_sink != null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/logs/dweis.log');
      await _logFile!.parent.create(recursive: true);
      _sink = _logFile!.openWrite(mode: FileMode.append);
    } catch (_) {
      _enabled = false;
    }
  }

  Future<void> _close() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }

  /// 获取日志文件内容
  Future<String> getLogs({int maxLines = 500}) async {
    if (_logFile == null || !await _logFile!.exists()) return '';
    try {
      final lines = await _logFile!.readAsLines();
      if (lines.length <= maxLines) return lines.join('\n');
      return lines.sublist(lines.length - maxLines).join('\n');
    } catch (_) {
      return '';
    }
  }

  /// 清空日志
  Future<void> clearLogs() async {
    try {
      await _sink?.flush();
      await _sink?.close();
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
      }
      _sink = null;
      if (_enabled) await _initFile();
    } catch (_) {}
  }

  /// 获取日志文件大小
  Future<int> getLogSize() async {
    if (_logFile == null || !await _logFile!.exists()) return 0;
    return _logFile!.length();
  }

  void _write(String level, String tag, String message) {
    if (!_enabled) return;
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    final line = '[$time] [$level] [$tag] $message\n';
    _sink?.write(line);
    if (kDebugMode) {
      debugPrint(line.trimRight());
    }
  }

  void d(String tag, String message) => _write('D', tag, message);
  void i(String tag, String message) => _write('I', tag, message);
  void w(String tag, String message) => _write('W', tag, message);
  void e(String tag, String message, [Object? error]) {
    _write('E', tag, '$message${error != null ? ' | $error' : ''}');
  }
}

/// 全局日志实例
final log = LogService();
