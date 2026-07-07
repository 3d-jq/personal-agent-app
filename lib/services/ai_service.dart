import 'dart:async';
import 'package:dio/dio.dart';
import '../tools/tools.dart';
import 'ai_service_base.dart';
import 'ai_service_openai.dart';
import 'ai_service_anthropic.dart';
import 'chat_stream_event.dart';
import 'log_service.dart';

export 'ai_service_base.dart' show AiResponse;

class AIService {
  final String baseUrl;
  final String apiKey;
  final String providerName;
  final String model;
  final ToolRegistry toolRegistry;
  final int maxTokens;
  final String thinkingEffort;

  AIService({
    required this.baseUrl,
    required this.apiKey,
    required this.providerName,
    required this.model,
    this.maxTokens = 65536,
    this.thinkingEffort = 'medium',
    ToolRegistry? toolRegistry,
  }) : toolRegistry = toolRegistry ?? ToolRegistry();

  bool get _isAnthropic => providerName == 'Anthropic';

  OpenAiProtocol get _openAi => OpenAiProtocol(
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: model,
    toolRegistry: toolRegistry,
    maxTokens: maxTokens,
    thinkingEffort: thinkingEffort,
  );

  AnthropicProtocol get _anthropic => AnthropicProtocol(
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: model,
    toolRegistry: toolRegistry,
    maxTokens: maxTokens,
  );

  /// Fetch available model IDs.
  Future<List<String>> fetchModels() async {
    if (_isAnthropic) throw Exception('Anthropic 不支持获取模型列表');
    final url = '${normalizeUrl(baseUrl)}/models';
    try {
      final response = await AiHttpClient.sharedDio.get(
        url,
        options: Options(headers: _openAi.authHeaders),
      );
      final data = response.data['data'] as List?;
      if (data == null) throw Exception('该厂商不支持获取模型列表');
      return data
          .map<String>((m) => (m['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList()
        ..sort();
    } catch (e) {
      throw Exception('获取模型列表失败: $e');
    }
  }

  /// Send messages with tool support.
  Stream<ChatStreamEvent> sendMessageStream(
    List<Map<String, dynamic>> messages,
  ) {
    return _sendMessageWithTools(messages);
  }

  /// 非流式摘要，用于 HistoryManager 压缩早期对话历史。
  Future<String> summarize(List<Map<String, dynamic>> messages) async {
    final url = '${normalizeUrl(baseUrl)}/chat/completions';
    log.i('AIService', 'Summarize request: ${messages.length} messages');
    try {
      final response = await AiHttpClient.retryPost(
        url,
        headers: _openAi.authHeaders,
        data: {
          'model': model,
          'messages': messages,
          'max_tokens': 2048,
          'temperature': 0.3,
        },
      );
      // 检查 HTTP 状态码
      final statusCode = response.statusCode;
      if (statusCode == null || statusCode >= 400) {
        log.e('AIService', 'Summarize failed: HTTP $statusCode');
        return '';
      }
      final choice = response.data['choices']?[0];
      final result = (choice?['message']?['content'] as String? ?? '').trim();
      log.i('AIService', 'Summarize success: ${result.length} chars');
      return result;
    } catch (e) {
      log.e('AIService', 'Summarize failed', e);
      return '';
    }
  }

  Stream<ChatStreamEvent> _sendMessageWithTools(
    List<Map<String, dynamic>> messages,
  ) async* {
    final hasTools = toolRegistry.all.isNotEmpty;
    const safetyLimit = 20;
    var round = 0;
    final conversation = List<Map<String, dynamic>>.from(messages);

    while (true) {
      round++;
      if (round > safetyLimit) return;

      if (_isAnthropic) {
        yield* _anthropic.streamWithTools(conversation);
        return;
      }

      final tools = hasTools ? toolRegistry.functionDefinitions : null;
      if (tools == null || tools.isEmpty) {
        yield* _openAi.stream(conversation);
        return;
      }

      final response = await _openAi.callNonStreaming(conversation, tools);

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

      yield* _openAi.stream(conversation, tools: tools);
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
      'content': assistantText,
      'tool_calls': toolCalls
          .map((tc) => {
                'id': tc.id,
                'type': 'function',
                'function': {'name': tc.name, 'arguments': tc.arguments},
              })
          .toList(),
    };
    messages.add(assistantMsg);

    final controller = StreamController<ChatStreamEvent>();
    final resultsFuture = executeAllTools(toolCalls, toolRegistry, controller.sink);
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
}
