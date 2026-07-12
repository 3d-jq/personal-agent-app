import 'dart:async';
import 'dart:convert';
import '../services/performance_monitor.dart';
import 'package:dio/dio.dart';
import '../tools/tools.dart';
import 'ai_service_base.dart';
import 'chat_stream_event.dart';
import 'log_service.dart';

/// OpenAI 协议实现
class OpenAiProtocol {
  final String baseUrl;
  final String apiKey;
  final String model;
  final ToolRegistry toolRegistry;
  final int maxTokens;
  final String thinkingEffort;

  OpenAiProtocol({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.toolRegistry,
    this.maxTokens = 65536,
    this.thinkingEffort = 'medium',
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
        return AiResponse(text: errorMsg);
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

      // 关键：用「流式」Utf8Decoder（跨块保持状态）替代逐块 utf8.decode。
      // 逐块独立解码会让被网络分包切断的多字节字符（emoji / 中文等）变成乱码；
      // 流式解码器能正确拼接跨块字符，allowMalformed 仅替换真正非法的字节序列。
      final stream = (response.data.stream as Stream<List<int>>)
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true));
      String buffer = '';

      final toolCallArgs = <int, StringBuffer>{};
      final toolCallIds = <int, String>{};
      final toolCallNames = <int, String>{};

      await for (final strChunk in stream) {
        buffer += strChunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data.isEmpty || data == '[DONE]') continue;
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
      }

      final remaining = buffer.trim();
      if (remaining.isNotEmpty && !remaining.startsWith('[DONE]')) {
        if (remaining.startsWith('data: ')) {
          try {
            final choice = firstChoice(jsonDecode(remaining.substring(6)));
            final finishReason = choice?['finish_reason'] as String?;
            if (finishReason == 'length') {
              yield ErrorEvent('回复被长度限制截断，请简化问题或分多次询问');
            }
            final delta = choice?['delta'];
            if (delta != null) {
              final reasoning = delta['reasoning_content'] as String?;
              if (reasoning != null && reasoning.isNotEmpty) {
                yield ThinkingChunkEvent(reasoning);
              }
              final content = delta['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield TextChunkEvent(content);
              }
            }
          } catch (e) {
            log.w('OpenAiProtocol', 'Parse remaining SSE error: $e');
          }
        }
      }

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
}
