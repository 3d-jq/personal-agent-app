import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../tools/tools.dart';
import 'chat_stream_event.dart';

String _normalizeUrl(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

String _friendlyError(DioException e) {
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

class AIService {
  final String baseUrl;
  final String apiKey;
  final String providerName;
  final String model;
  final ToolRegistry toolRegistry;

  static final Dio _sharedDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 2),
    ),
  );

  AIService({
    required this.baseUrl,
    required this.apiKey,
    required this.providerName,
    required this.model,
    this.maxTokens = 65536,
    this.thinkingEffort = 'medium',
    ToolRegistry? toolRegistry,
  }) : toolRegistry = toolRegistry ?? ToolRegistry();

  /// Max tokens for Anthropic requests. Can be overridden per instance.
  final int maxTokens;

  /// 思考强度: low / medium / high。对应 OpenAI 的 reasoning_effort 参数。
  /// 仅对支持推理的模型（如 o1/o3 系列）生效。
  final String thinkingEffort;

  bool get _isAnthropic => providerName == 'Anthropic';

  /// 按厂商返回合适的 max_tokens。
  /// Claude 当前输出上限已支持 32K，与其他厂商统一使用外部配置值。
  int get _effectiveMaxTokens => maxTokens;

  /// Retries a request on 429 / timeout / connection error with exponential backoff.
  /// [maxRetries] attempts total (including the first one).
  /// [receiveTimeout] overrides the default for long-running streaming requests.
  Future<Response> _retryPost(
    String url, {
    required Map<String, String> headers,
    required dynamic data,
    ResponseType? responseType,
    Duration? receiveTimeout,
    int maxRetries = 3,
  }) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final resp = await _sharedDio.post(
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
          final delay = Duration(seconds: (1 << attempt) + 1); // 2s, 3s, 5s
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
    throw Exception('unreachable');
  }

  Map<String, String> get _authHeaders => _isAnthropic
      ? {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        }
      : {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'};

  /// Fetch available model IDs.
  Future<List<String>> fetchModels() async {
    if (_isAnthropic) throw Exception('Anthropic 不支持获取模型列表');
    final url = '${_normalizeUrl(baseUrl)}/models';
    try {
      final response = await _sharedDio.get(
        url,
        options: Options(headers: _authHeaders),
      );
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
  Stream<ChatStreamEvent> sendMessageStream(
    List<Map<String, dynamic>> messages,
  ) {
    return _sendMessageWithTools(messages);
  }

  /// 非流式摘要，用于 HistoryManager 压缩早期对话历史。
  Future<String> summarize(List<Map<String, dynamic>> messages) async {
    final url = '${_normalizeUrl(baseUrl)}/chat/completions';
    try {
      final response = await _retryPost(
        url,
        headers: _authHeaders,
        data: {
          'model': model,
          'messages': messages,
          'max_tokens': 2048,
          'temperature': 0.3,
        },
      );
      final choice = response.data['choices']?[0];
      return (choice?['message']?['content'] as String? ?? '').trim();
    } on DioException catch (e) {
      return '';
    } catch (e) {
      return '';
    }
  }

  Future<AiResponse> _callOpenAINonStreaming(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
  ) async {
    final url = '${_normalizeUrl(baseUrl)}/chat/completions';
    try {
      final response = await _retryPost(
        url,
        headers: _authHeaders,
        data: {
          'model': model,
          'messages': messages,
          'tools': tools,
          'max_tokens': _effectiveMaxTokens,
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
      return AiResponse(text: _friendlyError(e));
    } catch (e) {
      return AiResponse(text: '请求异常: $e');
    }
  }

  // ── Tool-calling aware streaming ──

  Stream<ChatStreamEvent> _sendMessageWithTools(
    List<Map<String, dynamic>> messages,
  ) async* {
    final hasTools = toolRegistry.all.isNotEmpty;
    const safetyLimit = 20;
    var round = 0;
    // Work on a copy to avoid mutating the caller's list
    final conversation = List<Map<String, dynamic>>.from(messages);

    while (true) {
      round++;
      if (round > safetyLimit) return;

      // For Anthropic, always streaming with tool-call collection
      if (_isAnthropic) {
        yield* _streamAnthropicWithTools(conversation);
        return;
      }

      // OpenAI-compatible: use non-streaming first to reliably detect tool calls.
      final tools = hasTools ? toolRegistry.functionDefinitions : null;
      if (tools == null || tools.isEmpty) {
        yield* _streamOpenAI(conversation);
        return;
      }

      final response = await _callOpenAINonStreaming(conversation, tools);

      if (response.toolCalls != null && response.toolCalls!.isNotEmpty) {
        if (response.reasoning.isNotEmpty) {
          yield ThinkingChunkEvent(response.reasoning);
        }
        if (response.text.isNotEmpty) {
          yield TextChunkEvent(response.text);
        }
        yield* _processToolCalls(conversation, response.toolCalls!, response.text);
        continue;
      }

      if (response.reasoning.isNotEmpty) {
        yield ThinkingChunkEvent(response.reasoning);
      }
      if (response.text.isNotEmpty) {
        yield TextChunkEvent(response.text);
        return;
      }

      yield* _streamOpenAI(conversation, tools: tools);
      return;
    }
  }

  /// Shared tool execution engine. Returns events via [sink] and results via Future.
  Future<List<ToolResult>> _executeAllTools(
    List<ToolCall> toolCalls,
    EventSink<ChatStreamEvent> sink,
  ) async {
    try {
      final count = toolCalls.length;
      for (final tc in toolCalls) {
        sink.add(ToolStartEvent(tc.name, concurrentCount: count, arguments: tc.arguments));
      }

      final planCalls = toolCalls.where((tc) => tc.name == 'task_plan').toList();
      final otherCalls = toolCalls.where((tc) => tc.name != 'task_plan').toList();
      final results = <String, ToolResult>{};

      await Future.wait(
        otherCalls.map((tc) async {
          results[tc.id] = await toolRegistry.execute(tc);
        }),
      );

      for (final tc in planCalls) {
        results[tc.id] = await toolRegistry.execute(tc);
      }

      final ordered = <ToolResult>[];
      for (final tc in toolCalls) {
        final result = results[tc.id]!;
        ordered.add(result);
        if (result.failed) {
          sink.add(ToolErrorEvent(tc.name, result.content));
        } else {
          sink.add(ToolDoneEvent(tc.name));
        }
        if ((tc.name == 'generate_image' || tc.name == 'generate_video') &&
            result.content.isNotEmpty && !result.failed) {
          sink.add(ToolMediaEvent(result.content));
        }
        if (tc.name == 'task_plan' && result.content.isNotEmpty && !result.failed) {
          final plan = TaskPlanTool.currentPlan;
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

      return ordered;
    } finally {
      sink.close();
    }
  }

  // ── OpenAI format ──

  Stream<ChatStreamEvent> _processToolCalls(
    List<Map<String, dynamic>> messages,
    List<ToolCall> toolCalls,
    String assistantText,
  ) async* {
    final assistantMsg = {
      'role': 'assistant',
      'content': assistantText,
      'tool_calls': toolCalls
          .map((tc) => {
                'id': tc.id,
                'type': 'function',
                'function': {'name': tc.name, 'arguments': jsonEncode(tc.arguments)},
              })
          .toList(),
    };
    messages.add(assistantMsg);

    final controller = StreamController<ChatStreamEvent>();
    final resultsFuture = _executeAllTools(toolCalls, controller.sink);
    await for (final event in controller.stream) {
      yield event;
    }
    final results = await resultsFuture;

    for (var i = 0; i < toolCalls.length; i++) {
      messages.add({
        'role': 'tool',
        'tool_call_id': toolCalls[i].id,
        'content': results[i].content,
      });
    }

    yield ToolInteractionEvent(
      toolCalls: (assistantMsg['tool_calls'] as List).cast<Map<String, dynamic>>(),
      toolResults: List.generate(results.length,
          (i) => {'id': toolCalls[i].id, 'name': results[i].toolName, 'content': results[i].content}),
    );
  }


  /// Streams text chunks in real-time and collects tool calls into [outToolCalls].
  Stream<ChatStreamEvent> _streamOpenAI(
    List<Map<String, dynamic>> messages, {
    List<Map<String, dynamic>>? tools,
    List<ToolCall>? outToolCalls,
  }) async* {
    final url = '${_normalizeUrl(baseUrl)}/chat/completions';
    try {
      final response = await _retryPost(
        url,
        headers: _authHeaders,
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(
          minutes: 5,
        ), // Streaming needs longer timeout
        data: {
          'model': model,
          'messages': messages,
          'stream': true,
          'max_tokens': _effectiveMaxTokens,
          if (tools != null && tools.isNotEmpty) 'tools': tools,
          if (thinkingEffort != 'low')
            'chat_template_kwargs': {'enable_thinking': true},
          if (thinkingEffort.isNotEmpty) 'reasoning_effort': thinkingEffort,
        },
      );

      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';

      // Tool-call accumulation state (OpenAI streams tool calls via deltas)
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

            // Reasoning content
            final reasoning = delta['reasoning_content'] as String?;
            if (reasoning != null && reasoning.isNotEmpty)
              yield ThinkingChunkEvent(reasoning);

            // Tool calls — accumulated from streaming deltas
            final toolCallsDelta = delta['tool_calls'] as List?;
            if (toolCallsDelta != null && outToolCalls != null) {
              for (final tc in toolCallsDelta) {
                final idx = tc['index'] as int;
                // First chunk for this tool call: id + name
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

            // Text content (only yield if not a tool-call delta)
            final content = delta['content'] as String?;
            if (content != null && content.isNotEmpty)
              yield TextChunkEvent(content);
          } catch (_) {}
        }
      }

      // Process any remaining buffer content
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
              if (reasoning != null && reasoning.isNotEmpty)
                yield ThinkingChunkEvent(reasoning);
              final content = delta['content'] as String?;
              if (content != null && content.isNotEmpty)
                yield TextChunkEvent(content);
            }
          } catch (_) {}
        }
      }

      // Collect completed tool calls (sorted by index for deterministic order)
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
            } catch (_) {}
          }
          outToolCalls.add(ToolCall(id: id, name: name, arguments: args));
        }
      }
    } on DioException catch (e) {
      yield ErrorEvent(_friendlyError(e));
    } catch (e) {
      yield ErrorEvent('未知错误: $e');
    }
  }

  // ── Anthropic streaming with tools ──

  Stream<ChatStreamEvent> _streamAnthropicWithTools(
    List<Map<String, dynamic>> messages,
  ) async* {
    const safetyLimit = 20;
    var round = 0;
    var currentMessages = messages;

    while (true) {
      round++;
      if (round > safetyLimit) return;

      final toolCalls = <ToolCall>[];
      yield* _streamAnthropicOnce(currentMessages, outToolCalls: toolCalls);

      if (toolCalls.isNotEmpty) {
        // Build tool_use message in Anthropic format
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

        // Execute tools via shared engine
        final controller = StreamController<ChatStreamEvent>();
        final resultsFuture = _executeAllTools(toolCalls, controller.sink);
        await for (final event in controller.stream) {
          yield event;
        }
        final results = await resultsFuture;

        // Add tool results in Anthropic format
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

  /// Streams text chunks in real-time and collects tool calls into [outToolCalls].
  Stream<ChatStreamEvent> _streamAnthropicOnce(
    List<Map<String, dynamic>> messages, {
    required List<ToolCall> outToolCalls,
  }) async* {
    final url = '${_normalizeUrl(baseUrl)}/messages';
    final system = messages
        .where((m) => m['role'] == 'system')
        .map((m) => m['content'] ?? '')
        .join('\n');
    // Preserve role field — Anthropic API requires {role, content} in messages
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
      final response = await _retryPost(
        url,
        headers: _authHeaders,
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(
          minutes: 5,
        ), // Streaming needs longer timeout
        data: {
          'model': model,
          'max_tokens': _effectiveMaxTokens,
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
                  if (partialJson != null)
                    currentToolInputBuf.write(partialJson);
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
                  } catch (_) {}
                }
                outToolCalls.add(
                  ToolCall(
                    id: currentToolId!,
                    name: currentToolName!,
                    arguments: args,
                  ),
                );
                currentToolId = null;
                currentToolName = null;
                currentToolInputBuf.clear();
              }
            }
          } catch (_) {}
        }
      }
    } on DioException catch (e) {
      yield ErrorEvent(_friendlyError(e));
    } catch (e) {
      yield ErrorEvent('未知错误: $e');
    }
  }
}
