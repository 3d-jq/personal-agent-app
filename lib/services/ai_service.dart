import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../tools/tools.dart';
import 'chat_stream_event.dart';

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

  static final Dio _sharedDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(minutes: 2),
  ));

  /// Known tool failure prefixes — centralized to avoid scattered hardcoded checks.
  static const _failurePrefixes = [
    '执行失败', '错误', '创建提醒失败',
    '视频生成失败', '视频任务创建失败', '视频生成超时',
    '图片生成失败', '图片生成错误',
  ];

  static bool _isToolFailed(String toolName, String content) {
    for (final prefix in _failurePrefixes) {
      if (content.startsWith(prefix)) return true;
    }
    return false;
  }

  AIService({
    required this.baseUrl,
    required this.apiKey,
    required this.providerName,
    required this.model,
    this.maxTokens = 16384,
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

  /// Retries a request on 429 with exponential backoff.
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
        if (e.response?.statusCode == 429 && attempt < maxRetries - 1) {
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
      ? {'Content-Type': 'application/json', 'x-api-key': apiKey, 'anthropic-version': '2023-06-01'}
      : {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'};

  /// Fetch available model IDs.
  Future<List<String>> fetchModels() async {
    if (_isAnthropic) throw Exception('Anthropic 不支持获取模型列表');
    final url = '${_normalizeUrl(baseUrl)}/models';
    try {
      final response = await _sharedDio.get(url, options: Options(headers: _authHeaders));
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
  Stream<ChatStreamEvent> sendMessageStream(List<Map<String, dynamic>> messages) {
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
          'max_tokens': 1024,
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

  // ── Tool-calling aware streaming ──

  Stream<ChatStreamEvent> _sendMessageWithTools(List<Map<String, dynamic>> messages) async* {
    final hasTools = toolRegistry.all.isNotEmpty;
    const safetyLimit = 20;
    var round = 0;
    // Work on a copy to avoid mutating the caller's list
    final conversation = List<Map<String, dynamic>>.from(messages);

    while (true) {
      round++;
      if (round > safetyLimit) return;

      // For Anthropic, we do non-streaming tool calling (simpler)
      if (_isAnthropic) {
        yield* _streamAnthropicWithTools(conversation);
        return;
      }

      // OpenAI-compatible: streaming for normal responses, non-streaming for tool calls
      final tools = hasTools
          ? toolRegistry.functionDefinitions
          : null;

      // If no tools or last round, do streaming
      if (tools == null) {
        yield* _streamOpenAI(conversation);
        return;
      }

      // Try non-streaming first to check for tool calls
      final response = await _callOpenAINonStreaming(conversation, tools);

      if (response.toolCalls != null && response.toolCalls!.isNotEmpty) {
        // Yield any text before the tool calls
        if (response.text.isNotEmpty) yield TextChunkEvent(response.text);
        // Execute tools and add results to conversation
        yield* _processToolCalls(conversation, response.toolCalls!, response.text);
        continue;
      }

      // No tool calls — always stream the final response
      yield* _streamOpenAI(conversation, tools: tools);
      return;
    }
  }

  Stream<ChatStreamEvent> _processToolCalls(
    List<Map<String, dynamic>> messages,
    List<ToolCall> toolCalls,
    String assistantText,
  ) async* {
    final assistantMsg = {
      'role': 'assistant',
      'content': assistantText, // Always string — some providers reject null content
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

    // 先发出所有 ToolStartEvent（确保 ask_user 等阻塞性工具能在 UI 显示）
    final count = toolCalls.length;
    for (final tc in toolCalls) {
      yield ToolStartEvent(tc.name, concurrentCount: count);
    }

    // task_plan 操作共享可变计划状态，必须串行执行；其他独立工具可以并行。
    final planCalls = toolCalls.where((tc) => tc.name == 'task_plan').toList();
    final otherCalls = toolCalls.where((tc) => tc.name != 'task_plan').toList();

    final resultsById = <String, Map<String, dynamic>>{};

    // 非 task_plan 工具并行执行
    await Future.wait(
      otherCalls.map((tc) async {
        final result = await toolRegistry.execute(tc);
        resultsById[tc.id] = {'tc': tc, 'result': result};
      }),
    );

    // task_plan 调用串行执行，避免共享状态竞态
    for (final tc in planCalls) {
      final result = await toolRegistry.execute(tc);
      resultsById[tc.id] = {'tc': tc, 'result': result};
    }

    // 按原始 tool call 顺序重组结果
    final results = toolCalls.map((tc) => resultsById[tc.id]!).toList();

    // Yield done/error events and add results to messages in original order
    for (final entry in results) {
      final tc = entry['tc'] as ToolCall;
      final result = entry['result'] as ToolResult;
      final failed = _isToolFailed(tc.name, result.content);
      if (failed) {
        yield ToolErrorEvent(tc.name, result.content);
      } else {
        yield ToolDoneEvent(tc.name);
      }
      if ((tc.name == 'generate_image' || tc.name == 'generate_video') && result.content.isNotEmpty && !failed) {
        yield ToolMediaEvent(result.content);
      }
      if (tc.name == 'task_plan' && result.content.isNotEmpty && !failed) {
        final plan = TaskPlanTool.currentPlan;
        if (plan != null) {
          yield TaskPlanEvent(
            title: plan.title,
            verified: plan.verified,
            tasks: plan.tasks.map((t) => TaskPlanItem(
              id: t.id,
              title: t.title,
              done: t.status == TaskStatus.done,
              inProgress: t.status == TaskStatus.inProgress,
            )).toList(),
          );
        }
      }
      messages.add({
        'role': 'tool',
        'tool_call_id': tc.id,
        'content': result.content,
      });
    }

    // 持久化事件：输出本轮完整的工具交互记录
    yield ToolInteractionEvent(
      toolCalls: (assistantMsg['tool_calls'] as List).cast<Map<String, dynamic>>(),
      toolResults: results.map((e) {
        final tc = e['tc'] as ToolCall;
        final result = e['result'] as ToolResult;
        return {'id': tc.id, 'name': tc.name, 'content': result.content};
      }).toList(),
    );
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
          if (thinkingEffort != 'low') 'chat_template_kwargs': {'enable_thinking': true},
          if (thinkingEffort.isNotEmpty) 'reasoning_effort': thinkingEffort,
        },
      );

      final data = response.data;
      final choice = data['choices']?[0];
      if (choice == null || choice['message'] == null) {
        return const AiResponse(text: '');
      }

      final message = choice['message'];
      final text = (message['content'] as String? ?? '') +
          (choice['finish_reason'] == 'length' ? '\n\n[回复被长度限制截断，请简化问题或分多次询问]' : '');
      final toolCallsRaw = message['tool_calls'] as List?;
      final toolCalls = toolCallsRaw?.map((tc) => ToolCall.fromJson(tc)).toList();

      return AiResponse(text: text, toolCalls: toolCalls);
    } on DioException catch (e) {
      return AiResponse(text: _friendlyError(e));
    } catch (e) {
      return AiResponse(text: '请求异常: $e');
    }
  }

  // ── OpenAI-compatible streaming ──

  Stream<ChatStreamEvent> _streamOpenAI(List<Map<String, dynamic>> messages, {List<Map<String, dynamic>>? tools}) async* {
    final url = '${_normalizeUrl(baseUrl)}/chat/completions';
    try {
      final response = await _retryPost(
        url,
        headers: _authHeaders,
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(minutes: 5), // Streaming needs longer timeout
        data: {
          'model': model,
          'messages': messages,
          'stream': true,
          'max_tokens': _effectiveMaxTokens,
          if (tools != null && tools.isNotEmpty) 'tools': tools,
          if (thinkingEffort != 'low') 'chat_template_kwargs': {'enable_thinking': true},
          if (thinkingEffort.isNotEmpty) 'reasoning_effort': thinkingEffort,
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
            final choice = jsonDecode(data)['choices']?[0];
            final finishReason = choice?['finish_reason'] as String?;
            if (finishReason == 'length') {
              yield ErrorEvent('回复被长度限制截断，请简化问题或分多次询问');
            }
            final delta = choice?['delta'];
            if (delta == null) continue;
            final reasoning = delta['reasoning_content'] as String?;
            if (reasoning != null && reasoning.isNotEmpty) yield ThinkingChunkEvent(reasoning);
            final content = delta['content'] as String?;
            if (content != null && content.isNotEmpty) yield TextChunkEvent(content);
          } catch (_) {}
        }
      }
      // Process any remaining buffer content
      if (buffer.trim().isNotEmpty && !buffer.trim().startsWith('[DONE]')) {
        try {
          final data = buffer.trim();
          if (data.startsWith('data: ')) {
            final choice = jsonDecode(data.substring(6))['choices']?[0];
            final finishReason = choice?['finish_reason'] as String?;
            if (finishReason == 'length') {
              yield ErrorEvent('回复被长度限制截断，请简化问题或分多次询问');
            }
            final delta = choice?['delta'];
            if (delta != null) {
              final reasoning = delta['reasoning_content'] as String?;
              if (reasoning != null && reasoning.isNotEmpty) yield ThinkingChunkEvent(reasoning);
              final content = delta['content'] as String?;
              if (content != null && content.isNotEmpty) yield TextChunkEvent(content);
            }
          }
        } catch (_) {}
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
        // Build tool use message for Anthropic
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

        // task_plan 操作共享可变计划状态，必须串行执行；其他独立工具可以并行。
        final planCalls = toolCalls.where((tc) => tc.name == 'task_plan').toList();
        final otherCalls = toolCalls.where((tc) => tc.name != 'task_plan').toList();

        final resultsById = <String, Map<String, dynamic>>{};

        // 非 task_plan 工具并行执行
        await Future.wait(
          otherCalls.map((tc) async {
            final toolResult = await toolRegistry.execute(tc);
            resultsById[tc.id] = {'tc': tc, 'result': toolResult};
          }),
        );

        // task_plan 调用串行执行，避免共享状态竞态
        for (final tc in planCalls) {
          final toolResult = await toolRegistry.execute(tc);
          resultsById[tc.id] = {'tc': tc, 'result': toolResult};
        }

        // 按原始 tool call 顺序重组结果
        final results = toolCalls.map((tc) => resultsById[tc.id]!).toList();

        // Yield events and collect results in original order
        final toolResults = <Map<String, dynamic>>[];
        final count = results.length;
        for (final entry in results) {
          final tc = entry['tc'] as ToolCall;
          final toolResult = entry['result'] as ToolResult;
          yield ToolStartEvent(tc.name, concurrentCount: count);
          final failed = _isToolFailed(tc.name, toolResult.content);
          if (failed) {
            yield ToolErrorEvent(tc.name, toolResult.content);
          } else {
            yield ToolDoneEvent(tc.name);
          }
          if ((tc.name == 'generate_image' || tc.name == 'generate_video') && toolResult.content.isNotEmpty && !failed) {
            yield ToolMediaEvent(toolResult.content);
          }
          if (tc.name == 'task_plan' && toolResult.content.isNotEmpty && !failed) {
            final plan = TaskPlanTool.currentPlan;
            if (plan != null) {
              yield TaskPlanEvent(
                title: plan.title,
                verified: plan.verified,
                tasks: plan.tasks.map((t) => TaskPlanItem(
                  id: t.id,
                  title: t.title,
                  done: t.status == TaskStatus.done,
                  inProgress: t.status == TaskStatus.inProgress,
                )).toList(),
              );
            }
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

      return;
    }
  }

  /// Streams text chunks in real-time and collects tool calls into [outToolCalls].
  Stream<ChatStreamEvent> _streamAnthropicOnce(
    List<Map<String, dynamic>> messages, {
    required List<ToolCall> outToolCalls,
  }) async* {
    final url = '${_normalizeUrl(baseUrl)}/messages';
    final system = messages.where((m) => m['role'] == 'system').map((m) => m['content'] ?? '').join('\n');
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
        receiveTimeout: const Duration(minutes: 5), // Streaming needs longer timeout
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
                  if (partialJson != null) currentToolInputBuf.write(partialJson);
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
                    args = Map<String, dynamic>.from(jsonDecode(currentToolInputBuf.toString()));
                  } catch (_) {}
                }
                outToolCalls.add(ToolCall(
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
    } on DioException catch (e) {
      yield ErrorEvent(_friendlyError(e));
    } catch (e) {
      yield ErrorEvent('未知错误: $e');
    }
  }

}
