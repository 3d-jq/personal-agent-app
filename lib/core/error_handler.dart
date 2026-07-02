import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 全局错误处理入口。
///
/// 负责三处兜底：
/// 1. [runZonedGuarded] 捕获未处理的异步异常
/// 2. [FlutterError.onError] 捕获 Flutter framework 异常
/// 3. [ErrorWidget.builder] 替换默认的红屏错误页
class ErrorHandler {
  ErrorHandler._();

  /// 初始化所有全局错误捕获。
  ///
  /// 应在 [WidgetsFlutterBinding.ensureInitialized] 之后、
  /// [runApp] 之前调用。
  static void init() {
    FlutterError.onError = _handleFlutterError;
  }

  /// Zone 内的未捕获异常回调。
  static void logError(Object error, StackTrace stack) {
    _report('Uncaught zone error', error, stack);
  }

  static void _handleFlutterError(FlutterErrorDetails details) {
    _report('Flutter framework error', details.exception, details.stack);
  }

  static void _report(String label, Object error, StackTrace? stack) {
    // 生产环境可接入 Sentry/Crashlytics；目前仅打印以便调试。
    debugPrint('[$label] $error');
    if (stack != null) debugPrint(stack.toString());
  }

  /// 构建自定义错误占位 widget，替换默认红屏。
  static Widget buildErrorWidget(FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: const Color(0xFFFAF9F5),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFC1633F), size: 48),
            const SizedBox(height: 16),
            const Text(
              '页面出错了',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF141413),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '请重启应用或返回上一页重试。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF55524D)),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              Text(
                details.exception.toString(),
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 12, color: Color(0xFF55524D)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
