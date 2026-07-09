import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/log_service.dart';
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
    // 生产环境可接入 Sentry/Crashlytics；目前同时打印到控制台并落盘（崩溃留痕）。
    debugPrint('[$label] $error');
    if (stack != null) debugPrint(stack.toString());
    unawaited(log.recordFatal(label, error, stack));
  }

  /// 把底层异常映射为对用户友好的文案，避免把原始栈/异常信息直接抛给用户。
  static String humanizeError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socket') ||
        s.contains('network') ||
        s.contains('connection') ||
        s.contains('clientexception') ||
        s.contains('failed host lookup') ||
        s.contains('errno') ||
        s.contains('handshake')) {
      return '网络连接不太稳定，请检查网络后重试';
    }
    if (s.contains('timeout') || s.contains('timed out') || s.contains('deadline')) {
      return '请求超时了，请稍后再试一次';
    }
    if (s.contains('401') ||
        s.contains('unauthorized') ||
        s.contains('api key') ||
        s.contains('authentication') ||
        s.contains('invalid api')) {
      return '后端鉴权失败，请检查 API Key 配置';
    }
    if (s.contains('429') ||
        s.contains('rate limit') ||
        s.contains('too many requests')) {
      return '请求过于频繁，稍等片刻再试';
    }
    if (s.contains('quota') || s.contains('insufficient') || s.contains('billing')) {
      return '当前账户额度不足，请检查套餐';
    }
    if (s.contains('context length') ||
        (s.contains('token') && s.contains('exceed'))) {
      return '单次内容超出模型长度限制，试试分段发送';
    }
    return '出了点小问题，请稍后重试';
  }

  /// 构建自定义错误占位 widget，替换默认红屏。
  static Widget buildErrorWidget(FlutterErrorDetails details) {
    return Container(
      color: const Color(0xFFF2F2F7),
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning,
            color: Color(0xFFFF3B30),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            '页面出错了',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '请重启应用或返回上一页重试。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Color(0xFF3C3C43)),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
              ),
              child: Text(
                details.exception.toString(),
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 12, color: Color(0xFF3C3C43)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
