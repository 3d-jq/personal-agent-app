import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/log_service.dart';

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

  /// 原生层经此通道名把日志推回 Dart（onNativeLog 方法调用）。
  static const String _nativeLogMethod = 'onNativeLog';

  final MethodChannel _channel;
  final EventChannel _events;

  TerminalChannel([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(channelName),
        _events = const EventChannel(eventsName) {
    _registerNativeLogBridge();
  }

  /// 确保原生→Dart 日志桥只注册一次（[log] 是全局单例，多次注册无害但冗余）。
  static bool _nativeLogBridged = false;
  static void _registerNativeLogBridge() {
    if (_nativeLogBridged) return;
    // 纯 Dart 单元测试环境（绑定尚未初始化）下，setMethodCallHandler 会因
    // binaryMessenger 未就绪而断言失败；用 debugBindingType 安全探测，未初始化则跳过。
    // App 运行期绑定已就绪，会正常注册原生日志桥。
    if (BindingBase.debugBindingType() == null) return;
    _nativeLogBridged = true;
    // 注意：用真实通道名注册 handler，而非注入的测试通道，
    // 这样原生（使用 com.example/terminal）推来的日志才能被接收。
    const MethodChannel(channelName).setMethodCallHandler((call) async {
      if (call.method == _nativeLogMethod) {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final level = (args?['level'] as String?) ?? 'I';
        final tag = (args?['tag'] as String?) ?? 'TerminalNative';
        final message = (args?['message'] as String?) ?? '';
        routeNativeLog(level, tag, message);
      }
      return null;
    });
  }

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

/// 将原生层经 [TerminalChannel._nativeLogMethod] 推来的日志路由到 App 统一日志系统
/// （[LogService]），使终端沙箱的原生报错/问题也能在 App「运行日志」页看到，
/// 无需 adb 抓 logcat。
///
/// 单独抽为顶层函数便于单测：E→[log.e]、W→[log.w]、其余→[log.i]。
void routeNativeLog(String level, String tag, String message) {
  switch (level) {
    case 'E':
      log.e(tag, message);
    case 'W':
      log.w(tag, message);
    default:
      log.i(tag, message);
  }
}
