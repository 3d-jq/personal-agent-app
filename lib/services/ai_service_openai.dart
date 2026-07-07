import 'dart:async';
import 'dart:convert';
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
      final response = await AiHttpClient.retryPost(
        url,
        headers: authHeaders,
        data: {
          'model': model,
          'messages': messages,
          'tools': tools,
          'max_tokens': maxTokens,
          if (thinkingEffort != 'low')
            'chat_template_kwargs': {'enable_thinking': true},
          if (thinkingEffort.isNotEmpty) 'reasoning_effort': thinkingEffort,
        },
      );

      final choice = response.data['choices']?[0];
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
      final response = await AiHttpClient.retryPost(
        url,
        headers: authHeaders,
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(minutes: 5),
        data: {
          'model': model,
          'messages': messages,
          'stream': true,
          'max_tokens': maxTokens,
          if (tools != null && tools.isNotEmpty) 'tools': tools,
          if (thinkingEffort != 'low')
            'chat_template_kwargs': {'enable_thinking': true},
          if (thinkingEffort.isNotEmpty) 'reasoning_effort': thinkingEffort,
        },
      );

      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';

      final toolCallArgs = <int, StringBuffer>{};
      final toolCallIds = <int, String>{};
      final toolCallNames = <int, String>{};

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data.isEmpty || data == '[DONE]') continue;
          try {
            final choice = jsonDecode(data)['choices']?[0];
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
            final choice = jsonDecode(remaining.substring(6))['choices']?[0];
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
