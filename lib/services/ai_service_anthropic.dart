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
    final systemBlocks = system.isNotEmpty
        ? [
            {
              'type': 'text',
              'text': system,
              'cache_control': {'type': 'ephemeral'},
            }
          ]
        : null;

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
          if (systemBlocks != null) 'system': systemBlocks,
          'messages': conversation,
          if (hasTools) 'tools': tools,
          'stream': true,
        },
      );

      // 关键：用「流式」Utf8Decoder（跨块保持状态）替代逐块 utf8.decode。
      // 逐块独立解码会让被网络分包切断的多字节字符（emoji / 中文等）变成乱码；
      // 流式解码器能正确拼接跨块字符，allowMalformed 仅替换真正非法的字节序列。
      final stream = (response.data.stream as Stream<List<int>>)
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true));
      String buffer = '';
      String? currentToolId;
      String? currentToolName;
      final currentToolInputBuf = StringBuffer();

      await for (final strChunk in stream) {
        buffer += strChunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data.isEmpty) continue;
          try {
            final json = jsonDecode(data);
            final type = json['type'] as String?;

            if (type == 'message_start') {
            final usage = json['message']?['usage'];
            if (usage is Map) {
              final read = usage['cache_read_input_tokens'];
              final creation = usage['cache_creation_input_tokens'];
              if (read != null || creation != null) {
                log.i('AnthropicProtocol', 'Cache usage — read: $read, creation: $creation');
              }
            }
          } else if (type == 'content_block_delta') {
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

  /// 非流式摘要，用于 HistoryManager 压缩早期对话历史。
  /// Anthropic 没有独立的摘要端点，复用 Messages API（非流式）取文本。
  Future<String> summarize(List<Map<String, dynamic>> messages) async {
    final url = '${normalizeUrl(baseUrl)}/messages';
    final system = messages
        .where((m) => m['role'] == 'system')
        .map((m) => m['content'] ?? '')
        .join('\n');
    final conversation = messages.where((m) => m['role'] != 'system').toList();
    final systemBlocks = system.isNotEmpty
        ? [
            {
              'type': 'text',
              'text': system,
              'cache_control': {'type': 'ephemeral'},
            }
          ]
        : null;
    log.i('AnthropicProtocol', 'Summarize request: ${messages.length} messages');
    try {
      final response = await AiHttpClient.retryPost(
        url,
        headers: _authHeaders,
        data: {
          'model': model,
          'max_tokens': 2048,
          'temperature': 0.3,
          if (systemBlocks != null) 'system': systemBlocks,
          'messages': conversation,
        },
      );
      final statusCode = response.statusCode;
      if (statusCode == null || statusCode >= 400) {
        log.e('AnthropicProtocol', 'Summarize failed: HTTP $statusCode');
        return '';
      }
      final data = response.data;
      final content = data is Map ? data['content'] : null;
      if (content is List && content.isNotEmpty) {
        final text = content
            .whereType<Map>()
            .map((c) => (c['text'] ?? '').toString())
            .join('');
        log.i('AnthropicProtocol', 'Summarize success: ${text.length} chars');
        return text.trim();
      }
      return '';
    } catch (e) {
      log.e('AnthropicProtocol', 'Summarize failed', e);
      return '';
    }
  }
}
