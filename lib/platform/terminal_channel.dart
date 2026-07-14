import 'dart:async';

import 'package:flutter/services.dart';

/// 终端沙箱原生通道异常（环境未初始化 / 原生模块缺失等）。
class TerminalException implements Exception {
  final String message;
  final Object? cause;
  const TerminalException(this.message, [this.cause]);

  @override
  String toString() => 'TerminalException: $message';
}

/// 终端无头执行结果（AI 工具用，不占用可见 PTY）。
class TerminalExecResult {
  final String output;
  final int exitCode;
  final String state;
  final String error;

  const TerminalExecResult({
    required this.output,
    required this.exitCode,
    required this.state,
    required this.error,
  });

  factory TerminalExecResult.fromMap(Map<dynamic, dynamic> m) => TerminalExecResult(
        output: m['output']?.toString() ?? '',
        exitCode: (m['exitCode'] as num?)?.toInt() ?? -1,
        state: m['state']?.toString() ?? '',
        error: m['error']?.toString() ?? '',
      );
}

/// 终端沙箱原生能力通道封装。
///
/// 封装 [MethodChannel]('com.example/terminal') 与 [EventChannel]('com.example/terminal/events')，
/// 把 Kotlin 原生 PRoot + Ubuntu 终端宿主暴露的能力以类型安全方式提供给 Dart（工具层 / UI 层）。
///
/// 可见交互终端：原生把 PTY 原始字节（含 ANSI 转义）经 [EventChannel] 推流，
/// [output] 暴露为 [Uint8List] 字节流，由 xterm 渲染；用户输入经 [write] 发回。
/// AI 自动化走 [exec]（无头执行，返回完整输出 + 退出码）。
///
/// 可注入 [MethodChannel] 以便测试（默认使用真实通道名）。
class TerminalChannel {
  static const String channelName = 'com.example/terminal';
  static const String eventsName = 'com.example/terminal/events';

  final MethodChannel _channel;
  final EventChannel _events;

  TerminalChannel([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(channelName),
        _events = const EventChannel(eventsName);

  /// 确保底层 PRoot + Ubuntu 环境已初始化（解包 rootfs、生成 common.sh 等）。
  Future<bool> ensureReady() => _invoke<bool>('ensureReady');

  /// 启动一个可见交互终端会话（bash，进入 PRoot 环境）。
  Future<bool> start(String sessionId) =>
      _invoke<bool>('start', {'sessionId': sessionId});

  /// 向可见终端写入用户输入（原始键入字符串，UTF-8 编码后写入 PTY）。
  Future<bool> write(String sessionId, String data) =>
      _invoke<bool>('write', {'sessionId': sessionId, 'data': data});

  /// 在沙箱内无头执行命令，返回完整输出与退出码（AI 工具用）。
  Future<TerminalExecResult> exec(String command, {int timeoutMs = 30000}) async {
    final raw = await _invoke<Map<dynamic, dynamic>>('exec', {
      'command': command,
      'timeoutMs': timeoutMs,
      'key': 'agent_exec',
    });
    return TerminalExecResult.fromMap(raw);
  }

  /// 关闭可见终端会话。
  Future<bool> close(String sessionId) =>
      _invoke<bool>('close', {'sessionId': sessionId});

  /// 可见终端标准输出字节流（原始 PTY 字节，含 ANSI 转义序列）。
  ///
  /// 订阅顺序无关紧要，但建议在 [start] 之前订阅以不丢首屏输出（shell 提示符等）。
  Stream<Uint8List> get output =>
      _events.receiveBroadcastStream().cast<Uint8List>();

  Future<T> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      final result = await _channel.invokeMethod<T>(method, args);
      return result as T;
    } on PlatformException catch (e) {
      throw TerminalException(
        e.message ?? '终端操作失败: $method',
        e,
      );
    } on MissingPluginException catch (e) {
      throw TerminalException('终端原生模块未就绪（请使用 Android 构建）', e);
    }
  }
}
