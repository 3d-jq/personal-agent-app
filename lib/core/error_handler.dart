import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../core/design_tokens.dart';
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
  ///
  /// 通过 [Builder] 在构建期拿到 context，用 [AgentColors] 适配浅/暗双模，
  /// 不再写死浅色色值（暗色下原白底红字会刺眼且与环境割裂）。
  ///
  /// 关键改进：异常类型与信息**始终展示**（不再仅限 debug 模式），并在下方
  /// 提供「导出运行日志并分享」按钮——直击用户「看不到红色异常类型、只能复制
  /// 500 行控制台」的痛点，一键生成 Markdown 报告并发给开发者。
  static Widget buildErrorWidget(FlutterErrorDetails details) {
    return Builder(
      builder: (context) {
        final nc = AgentColors.of(context);
        final exceptionText = details.exception.toString();
        return Container(
          color: nc.background,
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: nc.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                '页面出错了',
                style: TextStyle(
                  fontSize: FontToken.headline,
                  fontWeight: WeightToken.semibold,
                  color: nc.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请重启应用或返回上一页重试。完整错误已记录，可一键导出日志。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: FontToken.body, color: nc.textSecondary),
              ),
              const SizedBox(height: 20),
              // 异常类型摘要：始终展示，对应原本红屏顶部那行异常类型
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: nc.surface,
                  borderRadius: BorderRadius.circular(RadiusToken.md),
                  border: Border.all(color: nc.divider, width: 0.5),
                ),
                child: SelectableText(
                  exceptionText,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: FontToken.small,
                    color: nc.textSecondary,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _shareLog(),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('导出运行日志并分享'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: nc.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 生成 Markdown 日志报告并用原生分享通道调起系统选择器。
  ///
  /// 与 UI 导航解耦（纯平台调用），即使在错误占位页也能安全触发。
  static Future<void> _shareLog() async {
    try {
      final path = await log.exportMarkdownReport();
      if (path == null) return;
      const channel = MethodChannel('com.example/share_file');
      await channel.invokeMethod('shareFile', {
        'path': path,
        'mimeType': 'text/markdown',
        'title': 'DWeis 运行日志',
      });
    } catch (_) {
      // 分享失败不影响主流程
    }
  }
}
