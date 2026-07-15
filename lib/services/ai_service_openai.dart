import 'dart:async';
import 'dart:convert';
import '../services/performance_monitor.dart';
import 'package:dio/dio.dart';
import '../tools/tools.dart';
import 'ai_service_base.dart';
import 'chat_stream_event.dart';
import 'log_service.dart';
import 'token_usage_tracker.dart';
import 'sse_parser.dart';

/// OpenAI 协议实现
class OpenAiProtocol {
  final String baseUrl;
  final String apiKey;
  final String model;
  final String provider;
  final ToolRegistry toolRegistry;
  final int maxTokens;
  final String thinkingEffort;
  /// Anthropic 协议：system 消息注入 cache_control 启用 prompt caching。
  /// OpenAI/兼容代理可能拒绝未知字段，故只对 Anthropic 启用。
  final bool enablePromptCache;

  OpenAiProtocol({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.provider = '',
    required this.toolRegistry,
    this.maxTokens = 65536,
    this.thinkingEffort = 'medium',
    this.enablePromptCache = false,
  });

  /// 从 SSE data (已 jsonDecode) 中取出 choices 的第一个元素。
  /// 兼容 choices 为 null / 空数组 / 非 Map 的情况（如 OpenAI 开启
  /// stream usage 时最后一个分片是 {"choices":[],"usage":{...}}）。
  static Map<String, dynamic>? firstChoice(dynamic decoded) {
    if (decoded is! Map) return null;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final c = choices[0];
    return c is Map<String, dynamic> ? c : null;
  }

  Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  /// 非流式请求（用于工具调用检测）
  Future<AiResponse> callNonStreaming(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
  ) async {
    final url = '${normalizeUrl(baseUrl)}/chat/completions';
    try {
      final patchedMessages = messages.map((m) {
        if (m['role'] == 'system' && m['content'] is String) {
          return {
            ...m,
            'content': [
              {
                'type': 'text',
                'text': m['content'],
                if (enablePromptCache)
                  'cache_control': {'type': 'ephemeral'},
              }
            ],
          };
        }
        return m;
      }).toList();
      final response = await AiHttpClient.retryPost(
        url,
        headers: authHeaders,
        data: {
          'model': model,
          'messages': patchedMessages,
          'tools': tools,
          'max_tokens': maxTokens,
          if (thinkingEffort != 'low')
            'chat_template_kwargs': {'enable_thinking': true},
          if (thinkingEffort.isNotEmpty) 'reasoning_effort': thinkingEffort,
        },
      );

      // 检查 HTTP 状态码
      final statusCode = response.statusCode;
      if (statusCode == null || statusCode >= 400) {
        final errorData = response.data;
        String errorMsg = '请求失败($statusCode)';
        if (errorData is Map) {
          final error = errorData['error'];
          if (error is Map) {
            errorMsg = error['message']?.toString() ?? errorMsg;
          }
        }
        log.e('OpenAiProtocol', 'Non-streaming request failed: $errorMsg');
        throw Exception('OpenAI non-streaming HTTP $statusCode: $errorMsg');
      }

      final choice = firstChoice(response.data);
      final usage = response.data is Map ? response.data['usage'] : null;
      if (usage is Map) {
        final details = usage['prompt_tokens_details'];
        final cached = details is Map ? details['cached_tokens'] : null;
        if (cached != null) {
          log.d('OpenAiProtocol', 'Cache usage — cached_tokens: $cached');
          perf.cacheHit('OpenAI', 'cached_tokens: $cached');
        }
        _recordUsage(usage);
      }
      if (choice == null || choice['message'] == null) {
        return const AiResponse(text: '');
      }
      final message = choice['message'];
      final reasoning = message['reasoning_content'] as String? ?? '';
      final text =
          (message['content'] as String? ?? '') +
          (choice['finish_reason'] == 'length'
              ? '\n\n[回复被长度限制截断，请简化问题或分多次询问]'
              : '');
      final toolCallsRaw = message['tool_calls'] as List?;
      final toolCalls = toolCallsRaw
          ?.map((tc) => ToolCall.fromJson(tc as Map<String, dynamic>))
          .toList();
      return AiResponse(text: text, reasoning: reasoning, toolCalls: toolCalls);
    } on DioException catch (e) {
      return AiResponse(text: friendlyError(e));
    } catch (e) {
      return AiResponse(text: '请求异常: $e');
    }
  }

  /// 流式请求
  Stream<ChatStreamEvent> stream(
    List<Map<String, dynamic>> messages, {
    List<Map<String, dynamic>>? tools,
    List<ToolCall>? outToolCalls,
  }) async* {
    final url = '${normalizeUrl(baseUrl)}/chat/completions';
    try {
      final patchedMessages = messages.map((m) {
        if (m['role'] == 'system' && m['content'] is String) {
          return {
            ...m,
            'content': [
              {
                'type': 'text',
                'text': m['content'],
                if (enablePromptCache)
                  'cache_control': {'type': 'ephemeral'},
              }
            ],
          };
        }
        return m;
      }).toList();
      final response = await AiHttpClient.retryPost(
        url,
        headers: authHeaders,
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(minutes: 5),
        data: {
          'model': model,
          'messages': patchedMessages,
          'stream': true,
          'stream_options': {'include_usage': true},
          'max_tokens': maxTokens,
          if (tools != null && tools.isNotEmpty) 'tools': tools,
          if (thinkingEffort != 'low')
            'chat_template_kwargs': {'enable_thinking': true},
          if (thinkingEffort.isNotEmpty) 'reasoning_effort': thinkingEffort,
        },
      );

      // 检查 HTTP 状态码
      final statusCode = response.statusCode;
      if (statusCode == null || statusCode >= 400) {
        // 读取错误响应
        String errorMsg = '请求失败($statusCode)';
        try {
          final errorBody = await response.data.stream.bytesToString();
          final errorData = jsonDecode(errorBody);
          if (errorData is Map) {
            final error = errorData['error'];
            if (error is Map) {
              errorMsg = error['message']?.toString() ?? errorMsg;
            }
          }
        } catch (_) {}
        log.e('OpenAiProtocol', 'Stream request failed: $errorMsg');
        yield ErrorEvent(errorMsg);
        return;
      }

      // SSE 行级解析由 SseParser 统一处理（buffer 管理、\r\n、大小上限）
      final toolCallArgs = <int, StringBuffer>{};
      final toolCallIds = <int, String>{};
      final toolCallNames = <int, String>{};
      Map<dynamic, dynamic>? lastUsage;

      await for (final data in SseParser.parse(response.data.stream)) {
        try {
            final decoded = jsonDecode(data);
            final usage = decoded is Map ? decoded['usage'] : null;
            if (usage is Map) {
              final details = usage['prompt_tokens_details'];
              final cached = details is Map ? details['cached_tokens'] : null;
              if (cached != null) {
                log.d('OpenAiProtocol', 'Cache usage — cached_tokens: $cached');
          perf.cacheHit('OpenAI', 'cached_tokens: $cached');
              }
              lastUsage = usage;
            }
            final choice = firstChoice(decoded);
            final finishReason = choice?['finish_reason'] as String?;
            if (finishReason == 'length') {
              yield ErrorEvent('回复被长度限制截断，请简化问题或分多次询问');
            }
            final delta = choice?['delta'];
            if (delta == null) continue;

            final reasoning = delta['reasoning_content'] as String?;
            if (reasoning != null && reasoning.isNotEmpty) {
              yield ThinkingChunkEvent(reasoning);
            }

            final toolCallsDelta = delta['tool_calls'] as List?;
            if (toolCallsDelta != null && outToolCalls != null) {
              for (final tc in toolCallsDelta) {
                final idx = tc['index'] as int;
                final id = tc['id'] as String?;
                if (id != null) toolCallIds[idx] = id;
                final func = tc['function'] as Map<String, dynamic>?;
                if (func != null) {
                  final name = func['name'] as String?;
                  if (name != null) toolCallNames[idx] = name;
                  final args = func['arguments'] as String?;
                  if (args != null) {
                    toolCallArgs.putIfAbsent(idx, () => StringBuffer());
                    toolCallArgs[idx]!.write(args);
                  }
                }
              }
            }

            final content = delta['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield TextChunkEvent(content);
            }
          } catch (e) {
            log.w('OpenAiProtocol', 'Parse SSE line error: $e');
          }
      }

      if (lastUsage != null) _recordUsage(lastUsage);

      if (outToolCalls != null && toolCallIds.isNotEmpty) {
        final indices = toolCallIds.keys.toList()..sort();
        for (final idx in indices) {
          final id = toolCallIds[idx];
          final name = toolCallNames[idx];
          if (id == null || name == null) continue;
          Map<String, dynamic> args = {};
          final argsBuf = toolCallArgs[idx];
          if (argsBuf != null && argsBuf.isNotEmpty) {
            try {
              args = Map<String, dynamic>.from(jsonDecode(argsBuf.toString()));
            } catch (e) {
              log.w('OpenAiProtocol', 'Parse tool args error: $e');
            }
          }
          outToolCalls.add(ToolCall(id: id, name: name, arguments: args));
        }
      }
    } on DioException catch (e) {
      yield ErrorEvent(friendlyError(e));
    } catch (e) {
      yield ErrorEvent('未知错误: $e');
    }
  }

  /// 上报一次请求的 token 用量到 [TokenUsageTracker]（vendor+model 归因）。
  void _recordUsage(Map<dynamic, dynamic> usage) {
    try {
      final input = usage['prompt_tokens'];
      final output = usage['completion_tokens'];
      final details = usage['prompt_tokens_details'];
      final cached = details is Map ? details['cached_tokens'] : null;
      if (input is int && output is int) {
        tokenTracker.record(
          vendor: provider.isEmpty ? 'OpenAI' : provider,
          model: model,
          inputTokens: input,
          outputTokens: output,
          cachedInputTokens: cached is int ? cached : 0,
        );
      }
    } catch (e) {
      log.w('OpenAiProtocol', '记录 token 用量失败: $e');
    }
  }
}
