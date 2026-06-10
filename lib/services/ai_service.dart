import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../tools/tools.dart';

String _normalizeUrl(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

String _friendlyError(DioException e) {
  final code = e.response?.statusCode;
  switch (code) {
    case 401: return 'API Key 无效或已过期（401）';
    case 403: return '没有访问权限或被拒绝（403）';
    case 404: return 'API 地址或模型不存在（404），请检查 URL 和模型名';
    case 429: return '请求过于频繁或额度不足（429）';
    case 500:
    case 502:
    case 503: return '服务端暂时不可用（$code）';
  }
  if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
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

/// Result of one AI request cycle
class AiResponse {
  final String text;
  final List<ToolCall>? toolCalls;

  const AiResponse({required this.text, this.toolCalls});
}

class AIService {
  final String baseUrl;
  final String apiKey;
  final String providerName;
  final String model;
  final ToolRegistry toolRegistry;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(minutes: 2),
  ));

  AIService({
    required this.baseUrl,
    required this.apiKey,
    required this.providerName,
    required this.model,
    ToolRegistry? toolRegistry,
  }) : toolRegistry = toolRegistry ?? ToolRegistry();

  bool get _isAnthropic => providerName == 'Anthropic';

  Map<String, String> get _authHeaders => _isAnthropic
      ? {'Content-Type': 'application/json', 'x-api-key': apiKey, 'anthropic-version': '2023-06-01'}
      : {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'};

  /// Fetch available model IDs.
  Future<List<String>> fetchModels() async {
    if (_isAnthropic) throw Exception('Anthropic 不支持获取模型列表');
    final url = '${_normalizeUrl(baseUrl)}/models';
    try {
      final response = await _dio.get(url, options: Options(headers: _authHeaders));
      final data = response.data['data'] as List?;
      if (data == null) throw Exception('该厂商不支持获取模型列表');
      return data
          .map<String>((m) => (m['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList()
        ..sort();
    } on DioException catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  /// Send messages with tool support.
  /// Returns a stream of AI responses. Tool calls are handled internally.
  Stream<String> sendMessageStream(List<Map<String, dynamic>> messages) {
    return _sendMessageWithTools(messages);
  }

  // ── Tool-calling aware streaming ──

  Stream<String> _sendMessageWithTools(List<Map<String, dynamic>> messages) async* {
    final hasTools = toolRegistry.all.isNotEmpty;
    const safetyLimit = 20;
    var round = 0;

    while (true) {
      round++;
      if (round > safetyLimit) return;

      // For Anthropic, we do non-streaming tool calling (simpler)
      if (_isAnthropic) {
        yield* _streamAnthropicWithTools(messages);
        return;
      }

      // OpenAI-compatible: streaming for normal responses, non-streaming for tool calls
      final tools = hasTools
          ? toolRegistry.functionDefinitions
          : null;

      // If no tools or last round, do streaming
      if (tools == null) {
        yield* _streamOpenAI(messages);
        return;
      }

      // Try non-streaming first to check for tool calls
      final response = await _callOpenAINonStreaming(messages, tools);

      if (response.toolCalls != null && response.toolCalls!.isNotEmpty) {
        // Yield any text before the tool calls
        if (response.text.isNotEmpty) yield response.text;
        // Execute tools and add results to conversation
        yield* _processToolCalls(messages, response.toolCalls!, response.text);
        continue;
      }

      // No tool calls — yield text directly if we have it, otherwise stream
      if (response.text.isNotEmpty) {
        // Yield in small chunks to simulate streaming feel
        final chars = response.text.runes.toList();
        for (var i = 0; i < chars.length; i += 3) {
          final end = (i + 3).clamp(0, chars.length);
          yield String.fromCharCodes(chars.sublist(i, end));
          await Future.delayed(const Duration(milliseconds: 1));
        }
      } else {
        yield* _streamOpenAI(messages, tools: tools);
      }
      return;
    }
  }

  Stream<String> _processToolCalls(
    List<Map<String, dynamic>> messages,
    List<ToolCall> toolCalls,
    String assistantText,
  ) async* {
    final assistantMsg = {
      'role': 'assistant',
      'content': assistantText.isNotEmpty ? assistantText : null,
      'tool_calls': toolCalls.map((tc) => {
        'id': tc.id,
        'type': 'function',
        'function': {
          'name': tc.name,
          'arguments': jsonEncode(tc.arguments),
        },
      }).toList(),
    };
    messages.add(assistantMsg);

    // Execute tools and yield status updates
    for (final tc in toolCalls) {
      yield '🔧 调用工具: ${tc.name}\n';
      final result = await toolRegistry.execute(tc);
      yield '✅ ${tc.name} 完成\n';
      if ((tc.name == 'generate_image' || tc.name == 'generate_video') && result.content.isNotEmpty) {
        yield '${result.content}\n';
      }
      messages.add({
        'role': 'tool',
        'tool_call_id': tc.id,
        'content': result.content,
      });
    }
  }

  Future<AiResponse> _callOpenAINonStreaming(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
  ) async {
    final url = '${_normalizeUrl(baseUrl)}/chat/completions';
    try {
      final response = await _dio.post(
        url,
        options: Options(headers: _authHeaders),
        data: {
          'model': model,
          'messages': messages,
          'tools': tools,
        },
      );

      final data = response.data;
      final choice = data['choices']?[0]?['message'];
      if (choice == null) {
        return const AiResponse(text: '');
      }

      final text = choice['content'] as String? ?? '';
      final toolCallsRaw = choice['tool_calls'] as List?;
      final toolCalls = toolCallsRaw?.map((tc) => ToolCall.fromJson(tc)).toList();

      return AiResponse(text: text, toolCalls: toolCalls);
    } on DioException catch (e) {
      return AiResponse(text: _friendlyError(e));
    }
  }

  // ── OpenAI-compatible streaming ──

  Stream<String> _streamOpenAI(List<Map<String, dynamic>> messages, {List<Map<String, dynamic>>? tools}) async* {
    final url = '${_normalizeUrl(baseUrl)}/chat/completions';
    try {
      final response = await _dio.post(
        url,
        options: Options(headers: _authHeaders, responseType: ResponseType.stream),
        data: {
          'model': model,
          'messages': messages,
          'stream': true,
          if (tools != null && tools.isNotEmpty) 'tools': tools,
        },
      );

      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';
      await for (final chunk in stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data.isEmpty || data == '[DONE]') continue;
          try {
            final content = jsonDecode(data)['choices']?[0]?['delta']?['content'] as String?;
            if (content != null && content.isNotEmpty) yield content;
          } catch (_) {}
        }
      }
    } on DioException catch (e) {
      yield _friendlyError(e);
    } catch (e) {
      yield '未知错误: $e';
    }
  }

  // ── Anthropic streaming with tools ──

  Stream<String> _streamAnthropicWithTools(
    List<Map<String, dynamic>> messages,
  ) async* {
    const safetyLimit = 20;
    var round = 0;
    var currentMessages = messages;

    while (true) {
      round++;
      if (round > safetyLimit) return;

      final result = await _streamAnthropicOnce(currentMessages);

      if (result.toolCalls != null && result.toolCalls!.isNotEmpty) {
        // Build tool use message for Anthropic
        final content = <Map<String, dynamic>>[];
        if (result.text.isNotEmpty) {
          content.add({'type': 'text', 'text': result.text});
        }
        for (final tc in result.toolCalls!) {
          content.add({
            'type': 'tool_use',
            'id': tc.id,
            'name': tc.name,
            'input': tc.arguments,
          });
        }
        currentMessages.add({'role': 'assistant', 'content': content});

        // Execute tools
        final toolResults = <Map<String, dynamic>>[];
        for (final tc in result.toolCalls!) {
          yield '🔧 调用工具: ${tc.name}\n';
          final toolResult = await toolRegistry.execute(tc);
          yield '✅ ${tc.name} 完成\n';
          if ((tc.name == 'generate_image' || tc.name == 'generate_video') && toolResult.content.isNotEmpty) {
            yield '${toolResult.content}\n';
          }
          toolResults.add({
            'type': 'tool_result',
            'tool_use_id': tc.id,
            'content': toolResult.content,
          });
        }
        currentMessages.add({'role': 'user', 'content': toolResults});
        continue;
      }

      // No tool calls, just yield text
      if (result.text.isNotEmpty) yield result.text;
      return;
    }
  }

  Future<AiResponse> _streamAnthropicOnce(
    List<Map<String, dynamic>> messages,
  ) async {
    final url = '${_normalizeUrl(baseUrl)}/messages';
    final system = messages.where((m) => m['role'] == 'system').map((m) => m['content'] ?? '').join('\n');
    final conversation = messages.where((m) => m['role'] != 'system').map((m) => m['content']).toList();

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
      final response = await _dio.post(
        url,
        options: Options(headers: _authHeaders, responseType: ResponseType.stream),
        data: {
          'model': model,
          'max_tokens': 4096,
          if (system.isNotEmpty) 'system': system,
          'messages': conversation,
          if (hasTools) 'tools': tools,
          'stream': true,
        },
      );

      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';
      String fullText = '';
      final toolCalls = <ToolCall>[];
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
                    fullText += text;
                  }
                } else if (delta['type'] == 'input_json_delta') {
                  final partialJson = delta['partial_json'] as String?;
                  if (partialJson != null) currentToolInputBuf.write(partialJson);
                }
              }
            } else if (type == 'content_block_start') {
              final block = json['content_block'];
              if (block is Map && block['type'] == 'tool_use') {
                currentToolId = block['id']?.toString() ?? '';
                currentToolName = block['name']?.toString() ?? '';
                currentToolInputBuf.clear();
                // Check if initial input is present
                final initialInput = block['input'];
                if (initialInput != null && initialInput is Map) {
                  currentToolInputBuf.write(jsonEncode(initialInput));
                }
              }
            } else if (type == 'content_block_stop') {
              // Finish current tool call
              if (currentToolId != null && currentToolName != null) {
                Map<String, dynamic> args = {};
                if (currentToolInputBuf.isNotEmpty) {
                  try {
                    args = Map<String, dynamic>.from(jsonDecode(currentToolInputBuf.toString()));
                  } catch (_) {}
                }
                toolCalls.add(ToolCall(
                  id: currentToolId!,
                  name: currentToolName!,
                  arguments: args,
                ));
                currentToolId = null;
                currentToolName = null;
                currentToolInputBuf.clear();
              }
            }
          } catch (_) {}
        }
      }

      return AiResponse(
        text: fullText,
        toolCalls: toolCalls.isEmpty ? null : toolCalls,
      );
    } on DioException catch (e) {
      return AiResponse(text: _friendlyError(e));
    }
  }

  // ── Legacy streaming (for backwards compatibility) ──

  Stream<String> _streamAnthropic(List<Map<String, String>> messages) async* {
    final url = '${_normalizeUrl(baseUrl)}/messages';
    final system = messages.where((m) => m['role'] == 'system').map((m) => m['content'] ?? '').join('\n');
    final conversation = messages.where((m) => m['role'] != 'system').map((m) => {'role': m['role'], 'content': m['content']}).toList();
    try {
      final response = await _dio.post(
        url,
        options: Options(headers: _authHeaders, responseType: ResponseType.stream),
        data: {'model': model, 'max_tokens': 4096, if (system.isNotEmpty) 'system': system, 'messages': conversation, 'stream': true},
      );
      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';
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
            if (json['type'] == 'content_block_delta') {
              final text = json['delta']?['text'] as String?;
              if (text != null && text.isNotEmpty) yield text;
            }
          } catch (_) {}
        }
      }
    } on DioException catch (e) {
      yield _friendlyError(e);
    }
  }
}
