import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 全局日志服务
///
/// 支持文件日志和控制台日志，可在设置中开关。
///
/// 增强能力（2026-07-09）：
/// - 时间戳含日期（yyyy-MM-dd HH:mm:ss.mmm）
/// - warn/error 支持附带 error 与 stack trace
/// - 文件超过阈值自动轮转（备份为 .1 后清空当前文件）
/// - [recordFatal] 即使日志开关关闭也会强制写盘，保证崩溃留痕
class LogService {
  static final LogService _instance = LogService._();
  factory LogService() => _instance;
  LogService._();

  /// 日志文件超过此大小（5MB）触发轮转
  static const int _maxLogBytes = 5 * 1024 * 1024;

  /// 每写入这么多行检查一次是否需要轮转（避免每行都 stat）
  static const int _rotateCheckInterval = 100;

  bool _enabled = true;
  IOSink? _sink;
  File? _logFile;
  int _writeCount = 0;

  /// 仅供测试注入：非 null 时用它替代 recordFatal 的真实文件写入，
  /// 避免 flutter test 环境下真实文件 I/O 卡顿。生产代码保持 null。
  Future<void> Function(String path, String content)? _testFileWriter;

  /// 仅供测试：注入文件写入实现。
  void setTestFileWriter(
      Future<void> Function(String path, String content)? writer) {
    _testFileWriter = writer;
  }

  bool get enabled => _enabled;

  /// 仅供测试：仅切换开关，不触发文件初始化（避免测试中真实文件 I/O）。
  void setEnabledFlagOnly(bool value) {
    _enabled = value;
  }

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
      _logFile = File('${dir.path}/dweis.log');
      await _logFile!.parent.create(recursive: true);
      _sink = _logFile!.openWrite(mode: FileMode.append);
    } catch (_) {
      _enabled = false;
    }
  }

  /// 确保日志文件路径已知（即使未启用，也用于崩溃落盘）
  Future<void> _ensureFilePath() async {
    if (_logFile != null) return;
    // 测试注入：直接用内存占位路径，彻底跳过磁盘（flutter test isolate 下
    // 真实文件 I/O 可能被杀软拦截而挂死）。recordFatal 在注入时会走
    // _testFileWriter，不会真正打开此文件。
    if (_testFileWriter != null) {
      _logFile = File('test://log_service_test');
      return;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/dweis.log');
      await _logFile!.parent.create(recursive: true);
    } catch (_) {}
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

  /// 文件超过阈值时轮转：旧文件备份为 .1，当前文件重新开始
  Future<void> _rotateIfNeeded() async {
    if (_sink == null || _logFile == null) return;
    try {
      final size = await _logFile!.length();
      if (size <= _maxLogBytes) return;
      await _sink!.flush();
      await _sink!.close();
      _sink = null;
      final backup = File('${_logFile!.path}.1');
      if (await backup.exists()) await backup.delete();
      await _logFile!.rename(backup.path);
      _sink = _logFile!.openWrite(mode: FileMode.append);
    } catch (_) {}
  }

  String _timestamp() {
    final now = DateTime.now();
    final y = now.year.toString();
    final mo = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$y-$mo-$d $h:$mi:$s.$ms';
  }

  void _write(String level, String tag, String message) {
    if (!_enabled) return;
    final line = '[${_timestamp()}] [$level] [$tag] $message\n';
    // 测试注入：纯内存写入，绕开真实文件 I/O（flutter test isolate 下可能卡死）。
    if (_testFileWriter != null) {
      unawaited(_testFileWriter!(_logFile?.path ?? 'memory', line));
      return;
    }
    _sink?.write(line);
    if (kDebugMode) {
      debugPrint(line.trimRight());
    }
    _writeCount++;
    if (_writeCount % _rotateCheckInterval == 0) {
      unawaited(_rotateIfNeeded());
    }
  }

  void d(String tag, String message) => _write('D', tag, message);
  void i(String tag, String message) => _write('I', tag, message);
  void w(String tag, String message, [Object? error, StackTrace? stack]) {
    var msg = message;
    if (error != null) msg += ' | $error';
    if (stack != null) msg += '\n$stack';
    _write('W', tag, msg);
  }

  void e(String tag, String message, [Object? error, StackTrace? stack]) {
    var msg = message;
    if (error != null) msg += ' | $error';
    if (stack != null) msg += '\n$stack';
    _write('E', tag, msg);
  }

  /// 记录致命错误（崩溃 / 未捕获异常）。
  /// 即使日志开关关闭也会写入文件，以保证现场崩溃时崩因仍留痕。
  Future<void> recordFatal(String label, Object error, StackTrace? stack) async {
    await _ensureFilePath();
    if (_logFile == null) return;
    final line = '[${_timestamp()}] [F] [$label] $error'
        '${stack != null ? '\n$stack' : ''}\n';
    try {
      if (_testFileWriter != null) {
        // 测试注入：纯内存写入，避免 flutter test isolate 下真实文件 I/O 卡死。
        await _testFileWriter!(_logFile!.path, line);
      } else if (_sink != null) {
        _sink!.write(line);
      } else {
        // 开关关闭时单独打开文件追加写入；用 writeAsString 单次完成，
        // 避免手动 openWrite+flush+close 在 Windows 上偶发挂死。
        await _logFile!.writeAsString(line, mode: FileMode.append);
      }
    } catch (_) {}
  }
}

/// 全局日志实例
final log = LogService();
