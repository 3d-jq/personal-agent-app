import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/ai_service_openai.dart';
import 'package:personal_agent_app/services/ai_service_base.dart';
import 'package:personal_agent_app/services/chat_stream_event.dart';
import 'package:personal_agent_app/tools/tool_registry.dart';
import 'package:personal_agent_app/tools/base_tool.dart';
import 'package:dio/dio.dart';

void main() {
  group('OpenAiProtocol', () {
    late OpenAiProtocol protocol;
    late ToolRegistry toolRegistry;

    setUp(() {
      toolRegistry = ToolRegistry();
      protocol = OpenAiProtocol(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        model: 'gpt-4',
        toolRegistry: toolRegistry,
        maxTokens: 4096,
        thinkingEffort: 'medium',
      );
    });

    group('authHeaders', () {
      test('returns correct headers with API key', () {
        final headers = protocol.authHeaders;
        expect(headers['Content-Type'], 'application/json');
        expect(headers['Authorization'], 'Bearer test-key');
      });

      test('includes Bearer prefix', () {
        final headers = protocol.authHeaders;
        expect(headers['Authorization'], startsWith('Bearer '));
      });
    });

    group('constructor', () {
      test('stores baseUrl', () {
        expect(protocol.baseUrl, 'https://api.openai.com/v1');
      });

      test('stores apiKey', () {
        expect(protocol.apiKey, 'test-key');
      });

      test('stores model', () {
        expect(protocol.model, 'gpt-4');
      });

      test('stores maxTokens', () {
        expect(protocol.maxTokens, 4096);
      });

      test('stores thinkingEffort', () {
        expect(protocol.thinkingEffort, 'medium');
      });

      test('uses default values when not provided', () {
        final defaultProtocol = OpenAiProtocol(
          baseUrl: 'https://api.example.com',
          apiKey: 'key',
          model: 'model',
          toolRegistry: ToolRegistry(),
        );
        expect(defaultProtocol.maxTokens, 65536);
        expect(defaultProtocol.thinkingEffort, 'medium');
      });
    });

    group('normalizeUrl', () {
      test('removes trailing slashes', () {
        expect(normalizeUrl('https://api.example.com/'), 'https://api.example.com');
        expect(normalizeUrl('https://api.example.com//'), 'https://api.example.com');
        expect(normalizeUrl('https://api.example.com///'), 'https://api.example.com');
      });

      test('does not remove trailing slash from path', () {
        expect(normalizeUrl('https://api.example.com/v1/'), 'https://api.example.com/v1');
      });

      test('trims whitespace', () {
        expect(normalizeUrl('  https://api.example.com  '), 'https://api.example.com');
      });

      test('handles empty string', () {
        expect(normalizeUrl(''), '');
      });
    });

    group('friendlyError', () {
      test('handles 401 error', () {
        final error = _createDioException(statusCode: 401);
        final message = friendlyError(error);
        expect(message, contains('401'));
        expect(message, contains('API Key'));
      });

      test('handles 403 error', () {
        final error = _createDioException(statusCode: 403);
        final message = friendlyError(error);
        expect(message, contains('403'));
        expect(message, contains('权限'));
      });

      test('handles 404 error', () {
        final error = _createDioException(statusCode: 404);
        final message = friendlyError(error);
        expect(message, contains('404'));
        expect(message, contains('不存在'));
      });

      test('handles 429 error', () {
        final error = _createDioException(statusCode: 429);
        final message = friendlyError(error);
        expect(message, contains('429'));
        expect(message, contains('频繁'));
      });

      test('handles 500 error', () {
        final error = _createDioException(statusCode: 500);
        final message = friendlyError(error);
        expect(message, contains('500'));
        expect(message, contains('服务端'));
      });

      test('handles 502 error', () {
        final error = _createDioException(statusCode: 502);
        final message = friendlyError(error);
        expect(message, contains('502'));
        expect(message, contains('服务端'));
      });

      test('handles 503 error', () {
        final error = _createDioException(statusCode: 503);
        final message = friendlyError(error);
        expect(message, contains('503'));
        expect(message, contains('服务端'));
      });

      test('handles unknown error', () {
        final error = _createDioException(statusCode: 999);
        final message = friendlyError(error);
        // The error message contains the status code or a generic message
        expect(message, isNotEmpty);
      });
    });

    group('AiResponse', () {
      test('creates response with text only', () {
        const response = AiResponse(text: 'Hello');
        expect(response.text, 'Hello');
        expect(response.reasoning, '');
        expect(response.toolCalls, isNull);
      });

      test('creates response with reasoning', () {
        const response = AiResponse(text: 'Answer', reasoning: 'Thinking...');
        expect(response.text, 'Answer');
        expect(response.reasoning, 'Thinking...');
      });

      test('creates response with tool calls', () {
        final toolCalls = [
          ToolCall(id: 'call_1', name: 'weather', arguments: {'city': 'Beijing'}),
        ];
        final response = AiResponse(text: 'Let me check', toolCalls: toolCalls);
        expect(response.toolCalls, hasLength(1));
        expect(response.toolCalls!.first.name, 'weather');
      });
    });

    group('ToolCall.fromJson', () {
      test('parses standard OpenAI format', () {
        final json = {
          'id': 'call_abc',
          'type': 'function',
          'function': {
            'name': 'weather',
            'arguments': '{"city":"Beijing"}',
          },
        };
        final tc = ToolCall.fromJson(json);
        expect(tc.id, 'call_abc');
        expect(tc.name, 'weather');
        expect(tc.arguments, {'city': 'Beijing'});
      });

      test('handles top-level arguments (non-OpenAI format)', () {
        final json = {
          'id': 'call_xyz',
          'name': 'search',
          'arguments': {'query': 'test'},
        };
        final tc = ToolCall.fromJson(json);
        expect(tc.id, 'call_xyz');
        expect(tc.name, 'search');
        expect(tc.arguments, {'query': 'test'});
      });

      test('handles empty arguments', () {
        final json = {
          'id': 'call_empty',
          'type': 'function',
          'function': {'name': 'ping', 'arguments': '{}'},
        };
        final tc = ToolCall.fromJson(json);
        expect(tc.arguments, isEmpty);
      });

      test('handles malformed JSON arguments', () {
        final json = {
          'id': 'call_bad',
          'type': 'function',
          'function': {'name': 'bad', 'arguments': 'not json'},
        };
        final tc = ToolCall.fromJson(json);
        expect(tc.arguments, isEmpty);
      });

      test('handles missing id', () {
        final json = {
          'type': 'function',
          'function': {'name': 'test', 'arguments': '{}'},
        };
        final tc = ToolCall.fromJson(json);
        expect(tc.id, '');
      });

      test('handles missing name', () {
        final json = {
          'id': 'call_1',
          'type': 'function',
          'function': {'arguments': '{}'},
        };
        final tc = ToolCall.fromJson(json);
        expect(tc.name, '');
      });
    });

    group('ToolResult', () {
      test('creates success result', () {
        final result = ToolResult.success(
          toolName: 'weather',
          content: '北京 26°C 晴',
        );
        expect(result.toolName, 'weather');
        expect(result.content, '北京 26°C 晴');
        expect(result.isSuccess, isTrue);
        expect(result.failed, isFalse);
      });

      test('creates failure result', () {
        final result = ToolResult.failure(
          toolName: 'weather',
          content: '网络错误',
        );
        expect(result.toolName, 'weather');
        expect(result.content, '网络错误');
        expect(result.isSuccess, isFalse);
        expect(result.failed, isTrue);
      });

      test('defaults to success', () {
        final result = ToolResult(
          toolName: 'test',
          content: 'ok',
        );
        expect(result.isSuccess, isTrue);
        expect(result.failed, isFalse);
      });

      test('includes warning when provided', () {
        final result = ToolResult.success(
          toolName: 'search',
          content: 'results',
          warning: '频繁调用',
        );
        expect(result.warning, '频繁调用');
      });

      test('includes toolCallId when provided', () {
        final result = ToolResult.success(
          toolName: 'test',
          content: 'ok',
          toolCallId: 'call_123',
        );
        expect(result.toolCallId, 'call_123');
      });
    });
  });

  group('SSE parsing simulation', () {
    test('parses text delta from SSE line', () {
      final events = _parseSSELine('data: {"choices":[{"delta":{"content":"Hello"}}]}');
      expect(events, hasLength(1));
      expect(events.first, isA<TextChunkEvent>());
      expect((events.first as TextChunkEvent).text, 'Hello');
    });

    test('parses reasoning delta from SSE line', () {
      final events = _parseSSELine(
        'data: {"choices":[{"delta":{"reasoning_content":"Let me think..."}}]}',
      );
      expect(events, hasLength(1));
      expect(events.first, isA<ThinkingChunkEvent>());
      expect((events.first as ThinkingChunkEvent).text, 'Let me think...');
    });

    test('parses tool call id and name from SSE delta', () {
      final result = _parseSSEWithToolCalls([
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_123","type":"function","function":{"name":"weather","arguments":""}}]}}]}',
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"city\\":\\"Beijing\\"}"}}]}}]}',
      ]);
      expect(result.toolCalls, hasLength(1));
      expect(result.toolCalls.first.id, 'call_123');
      expect(result.toolCalls.first.name, 'weather');
      expect(result.toolCalls.first.arguments, {'city': 'Beijing'});
    });

    test('ignores [DONE] marker', () {
      final events = _parseSSELine('data: [DONE]');
      expect(events, isEmpty);
    });

    test('ignores empty data', () {
      final events = _parseSSELine('data: ');
      expect(events, isEmpty);
    });

    test('ignores non-data lines', () {
      final events = _parseSSELine(':ping');
      expect(events, isEmpty);
    });

    test('handles finish_reason length', () {
      final events = _parseSSELine(
        'data: {"choices":[{"finish_reason":"length","delta":{}}]}',
      );
      expect(events, hasLength(1));
      expect(events.first, isA<ErrorEvent>());
      expect((events.first as ErrorEvent).message, contains('截断'));
    });

    test('parses multiple deltas in order', () {
      final lines = [
        'data: {"choices":[{"delta":{"content":"The weather is "}}]}',
        'data: {"choices":[{"delta":{"content":"sunny"}}]}',
        'data: [DONE]',
      ];
      final result = _parseSSEWithToolCalls(lines);
      expect(result.events, hasLength(2));
      expect(result.events[0], isA<TextChunkEvent>());
      expect((result.events[0] as TextChunkEvent).text, 'The weather is ');
      expect(result.events[1], isA<TextChunkEvent>());
      expect((result.events[1] as TextChunkEvent).text, 'sunny');
    });
  });
}

// ── Test helpers ──

class _SSEParseResult {
  final List<ChatStreamEvent> events;
  final List<ToolCall> toolCalls;
  _SSEParseResult(this.events, this.toolCalls);
}

List<ChatStreamEvent> _parseSSELine(String line) {
  final events = <ChatStreamEvent>[];
  if (!line.startsWith('data: ')) return events;
  final data = line.substring(6).trim();
  if (data.isEmpty || data == '[DONE]') return events;
  try {
    final choice = jsonDecode(data)['choices']?[0];
    final finishReason = choice?['finish_reason'] as String?;
    if (finishReason == 'length') {
      events.add(ErrorEvent('回复被长度限制截断，请简化问题或分多次询问'));
    }
    final delta = choice?['delta'];
    if (delta == null) return events;

    final reasoning = delta['reasoning_content'] as String?;
    if (reasoning != null && reasoning.isNotEmpty) {
      events.add(ThinkingChunkEvent(reasoning));
    }
    final content = delta['content'] as String?;
    if (content != null && content.isNotEmpty) {
      events.add(TextChunkEvent(content));
    }
  } catch (_) {}
  return events;
}

_SSEParseResult _parseSSEWithToolCalls(List<String> lines) {
  final events = <ChatStreamEvent>[];
  final toolCallIds = <int, String>{};
  final toolCallNames = <int, String>{};
  final toolCallArgs = <int, StringBuffer>{};

  for (final line in lines) {
    if (!line.startsWith('data: ')) continue;
    final data = line.substring(6).trim();
    if (data.isEmpty || data == '[DONE]') continue;
    try {
      final choice = jsonDecode(data)['choices']?[0];
      final delta = choice?['delta'];
      if (delta == null) continue;

      final reasoning = delta['reasoning_content'] as String?;
      if (reasoning != null && reasoning.isNotEmpty) {
        events.add(ThinkingChunkEvent(reasoning));
      }
      final content = delta['content'] as String?;
      if (content != null && content.isNotEmpty) {
        events.add(TextChunkEvent(content));
      }

      final tcs = delta['tool_calls'] as List?;
      if (tcs != null) {
        for (final tc in tcs) {
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
    } catch (_) {}
  }

  final toolCalls = <ToolCall>[];
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
    toolCalls.add(ToolCall(id: id, name: name, arguments: args));
  }

  return _SSEParseResult(events, toolCalls);
}

DioException _createDioException({required int statusCode, dynamic responseData}) {
  return DioException(
    requestOptions: RequestOptions(path: ''),
    response: Response(
      requestOptions: RequestOptions(path: ''),
      statusCode: statusCode,
      data: responseData ?? {'error': {'message': 'Test error'}},
    ),
  );
}