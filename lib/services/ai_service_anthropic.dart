import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../tools/tools.dart';
import 'ai_service_base.dart';
import 'chat_stream_event.dart';
import 'log_service.dart';

/// Anthropic 协议实现
class AnthropicProtocol {
  final String baseUrl;
  final String apiKey;
  final String model;
  final ToolRegistry toolRegistry;
  final int maxTokens;

  AnthropicProtocol({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.toolRegistry,
    this.maxTokens = 65536,
  });

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'x-api-key': apiKey,
    'anthropic-version': '2023-06-01',
  };

  /// 流式请求（带工具循环）
  Stream<ChatStreamEvent> streamWithTools(
    List<Map<String, dynamic>> messages,
  ) async* {
    const safetyLimit = 20;
    var round = 0;
    var currentMessages = messages;

    while (true) {
      round++;
      if (round > safetyLimit) return;

      final toolCalls = <ToolCall>[];
      yield* _streamOnce(currentMessages, outToolCalls: toolCalls);

      if (toolCalls.isNotEmpty) {
        final content = <Map<String, dynamic>>[];
        for (final tc in toolCalls) {
          content.add({
            'type': 'tool_use',
            'id': tc.id,
            'name': tc.name,
            'input': tc.arguments,
          });
        }
        currentMessages.add({'role': 'assistant', 'content': content});

        final controller = StreamController<ChatStreamEvent>();
        final resultsFuture = executeAllTools(toolCalls, toolRegistry, controller.sink);
        await for (final event in controller.stream) {
          yield event;
        }
        final results = await resultsFuture;

        final toolResults = <Map<String, dynamic>>[];
        for (var i = 0; i < toolCalls.length; i++) {
          toolResults.add({
            'type': 'tool_result',
            'tool_use_id': toolCalls[i].id,
            'content': results[i].content,
          });
        }
        currentMessages.add({'role': 'user', 'content': toolResults});
        continue;
      }

      return;
    }
  }

  /// 单次流式请求
  Stream<ChatStreamEvent> _streamOnce(
    List<Map<String, dynamic>> messages, {
    required List<ToolCall> outToolCalls,
  }) async* {
    final url = '${normalizeUrl(baseUrl)}/messages';
    final system = messages
        .where((m) => m['role'] == 'system')
        .map((m) => m['content'] ?? '')
        .join('\n');
    final conversation = messages.where((m) => m['role'] != 'system').toList();

    final tools = toolRegistry.all.isNotEmpty
        ? toolRegistry.functionDefinitions.map((t) {
            final f = t['function'] as Map<String, dynamic>;
            return {
              'name': f['name'],
              'description': f['description'],
              'input_schema': f['parameters'],
            };
          }).toList()
        : null;

    final hasTools = tools != null && tools.isNotEmpty;

    try {
      final response = await AiHttpClient.retryPost(
        url,
        headers: _authHeaders,
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(minutes: 5),
        data: {
          'model': model,
          'max_tokens': maxTokens,
          if (system.isNotEmpty) 'system': system,
          'messages': conversation,
          if (hasTools) 'tools': tools,
          'stream': true,
        },
      );

      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';
      String? currentToolId;
      String? currentToolName;
      final currentToolInputBuf = StringBuffer();

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data.isEmpty) continue;
          try {
            final json = jsonDecode(data);
            final type = json['type'] as String?;

            if (type == 'content_block_delta') {
              final delta = json['delta'];
              if (delta is Map) {
                if (delta['type'] == 'text_delta') {
                  final text = delta['text'] as String?;
                  if (text != null && text.isNotEmpty) {
                    yield TextChunkEvent(text);
                  }
                } else if (delta['type'] == 'input_json_delta') {
                  final partialJson = delta['partial_json'] as String?;
                  if (partialJson != null) {
                    currentToolInputBuf.write(partialJson);
                  }
                }
              }
            } else if (type == 'content_block_start') {
              final block = json['content_block'];
              if (block is Map && block['type'] == 'tool_use') {
                currentToolId = block['id']?.toString() ?? '';
                currentToolName = block['name']?.toString() ?? '';
                currentToolInputBuf.clear();
                final initialInput = block['input'];
                if (initialInput != null && initialInput is Map) {
                  currentToolInputBuf.write(jsonEncode(initialInput));
                }
              }
            } else if (type == 'content_block_stop') {
              if (currentToolId != null && currentToolName != null) {
                Map<String, dynamic> args = {};
                if (currentToolInputBuf.isNotEmpty) {
                  try {
                    args = Map<String, dynamic>.from(
                      jsonDecode(currentToolInputBuf.toString()),
                    );
                  } catch (e) {
                    log.w('AnthropicProtocol', 'Parse tool args error: $e');
                  }
                }
                outToolCalls.add(
                  ToolCall(
                    id: currentToolId,
                    name: currentToolName,
                    arguments: args,
                  ),
                );
                currentToolId = null;
                currentToolName = null;
                currentToolInputBuf.clear();
              }
            }
          } catch (e) {
            log.w('AnthropicProtocol', 'Parse SSE line error: $e');
          }
        }
      }
    } on DioException catch (e) {
      yield ErrorEvent(friendlyError(e));
    } catch (e) {
      yield ErrorEvent('未知错误: $e');
    }
  }
}
