import 'dart:async';
import 'package:dio/dio.dart';
import '../tools/tools.dart';
import '../tools/tool_progress_bus.dart';
import '../services/log_service.dart';
import 'chat_stream_event.dart';

String normalizeUrl(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

String friendlyError(DioException e) {
  final code = e.response?.statusCode;
  switch (code) {
    case 401:
      return 'API Key 无效或已过期（401）';
    case 403:
      return '没有访问权限或被拒绝（403）';
    case 404:
      return 'API 地址或模型不存在（404），请检查 URL 和模型名';
    case 429:
      return '请求过于频繁或额度不足（429）';
    case 500:
    case 502:
    case 503:
      return '服务端暂时不可用（$code）';
  }
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return '网络超时，请检查网络或 Base URL';
  }
  if (e.type == DioExceptionType.connectionError) {
    return '无法连接到服务器，请检查网络或 API URL 是否正确';
  }
  final raw = e.response?.data;
  if (raw is Map) {
    final err = raw['error'];
    if (err is Map) return err['message']?.toString() ?? '未知错误';
  }
  return '请求失败${code != null ? ' ($code)' : ''}，请检查网络连接';
}

class AiResponse {
  final String text;
  final String reasoning;
  final List<ToolCall>? toolCalls;

  const AiResponse({required this.text, this.reasoning = '', this.toolCalls});
}

/// 共享的 HTTP 客户端和重试逻辑
class AiHttpClient {
  static final Dio sharedDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 2),
    ),
  );

  /// Retries a request on 429 / timeout / connection error with exponential backoff.
  static Future<Response> retryPost(
    String url, {
    required Map<String, String> headers,
    required dynamic data,
    ResponseType? responseType,
    Duration? receiveTimeout,
    int maxRetries = 3,
  }) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final resp = await sharedDio.post(
          url,
          options: Options(
            headers: headers,
            responseType: responseType,
            receiveTimeout: receiveTimeout,
          ),
          data: data,
        );
        return resp;
      } on DioException catch (e) {
        final is429 = e.response?.statusCode == 429;
        final isNetworkError = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;
        final shouldRetry = attempt < maxRetries - 1 && (is429 || isNetworkError);
        if (shouldRetry) {
          final delay = Duration(seconds: (1 << attempt) + 1);
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
    throw Exception('unreachable');
  }
}

/// 工具执行引擎（OpenAI 和 Anthropic 共享）
Future<List<ToolResult>> executeAllTools(
  List<ToolCall> toolCalls,
  ToolRegistry toolRegistry,
  EventSink<ChatStreamEvent> sink,
) async {
  final batchSw = Stopwatch()..start();
  try {
    final count = toolCalls.length;
    // 整体进度汇总（最高优先级，UI 可据此画总进度条）
    ToolProgressBus.instance.updateDetailed(
      ToolProgressBus.summaryToolName,
      0.0,
      message: '执行 $count 个工具',
    );

    for (final tc in toolCalls) {
      sink.add(ToolStartEvent(
        tc.name,
        id: tc.id,
        concurrentCount: count,
        arguments: tc.arguments,
      ));
    }

    final planCalls = toolCalls.where((tc) => tc.name == 'task_plan').toList();
    final otherCalls = toolCalls.where((tc) => tc.name != 'task_plan').toList();
    final results = <String, ToolResult>{};
    var done = 0;

    // 单工具执行包装：计时 + 进度汇总（保持原 Future.wait 并发结构不变，
    // 不触碰 delegate_task 阻塞式内核）。
    Future<void> runOne(ToolCall tc) async {
      final sw = Stopwatch()..start();
      results[tc.id] = await toolRegistry.execute(tc);
      done++;
      ToolProgressBus.instance.updateDetailed(
        ToolProgressBus.summaryToolName,
        done / count,
        message: '已完成 $done/$count',
      );
      log.i('ToolExec', '${tc.name} 耗时 ${sw.elapsedMilliseconds}ms');
    }

    await Future.wait(otherCalls.map(runOne));

    for (final tc in planCalls) {
      await runOne(tc);
    }

    final ordered = <ToolResult>[];
    for (final tc in toolCalls) {
      final result = results[tc.id]!;
      ordered.add(result);
      if (result.failed) {
        sink.add(ToolErrorEvent(tc.id, tc.name, result.content));
      } else {
        sink.add(ToolDoneEvent(tc.id, tc.name));
      }
      if ((tc.name == 'generate_image' || tc.name == 'generate_video') &&
          result.content.isNotEmpty && !result.failed) {
        sink.add(ToolMediaEvent(result.content));
      }
      if (tc.name == 'task_plan' && result.content.isNotEmpty && !result.failed) {
        final taskPlanTool = toolRegistry.get('task_plan');
        final plan = taskPlanTool is TaskPlanTool ? taskPlanTool.currentPlan : null;
        if (plan != null) {
          sink.add(TaskPlanEvent(
            title: plan.title,
            verified: plan.verified,
            tasks: plan.tasks
                .map((t) => TaskPlanItem(
                      id: t.id,
                      title: t.title,
                      done: t.status == TaskStatus.done,
                      inProgress: t.status == TaskStatus.inProgress,
                    ))
                .toList(),
          ));
        }
      }
    }

    ToolProgressBus.instance.clear();
    log.i('ToolExec', '批次完成 $count 个工具，总耗时 ${batchSw.elapsedMilliseconds}ms');
    return ordered;
  } finally {
    sink.close();
  }
}
