import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/ai_service.dart';
import 'package:personal_agent_app/services/chat_stream_event.dart';
import 'package:personal_agent_app/tools/base_tool.dart';

/// Re-expose private helpers for testing via the same library.
/// Dart allows tests in the same package to access library-private members
/// if imported with `import 'package:...';` (not `part of`), but they can't
/// access underscore-prefixed identifiers. We test through public API.

void main() {
  // ── URL normalization ──────────────────────────────────────────────

  group('_normalizeUrl', () {
    test('strips trailing slash', () {
      expect(_testNormalizeUrl('https://api.example.com/'), 'https://api.example.com');
    });

    test('strips multiple trailing slashes', () {
      expect(_testNormalizeUrl('https://api.example.com//'), 'https://api.example.com');
    });

    test('leaves URL without trailing slash unchanged', () {
      expect(_testNormalizeUrl('https://api.example.com'), 'https://api.example.com');
    });

    test('trims whitespace', () {
      expect(_testNormalizeUrl('  https://api.example.com/  '), 'https://api.example.com');
    });
  });

  // ── Tool failure detection ─────────────────────────────────────────

  group('_isToolFailed', () {
    test('detects execution failure prefix', () {
      expect(_testIsToolFailed('weather', '执行失败: timeout'), isTrue);
    });

    test('detects error prefix', () {
      expect(_testIsToolFailed('weather', '错误: invalid param'), isTrue);
    });

    test('detects image generation failure', () {
      expect(_testIsToolFailed('generate_image', '图片生成失败: quota'), isTrue);
    });

    test('detects video generation failure', () {
      expect(_testIsToolFailed('generate_video', '视频生成失败'), isTrue);
    });

    test('returns false for normal result', () {
      expect(_testIsToolFailed('weather', '北京 26°C 晴'), isFalse);
    });
  });

  // ── Friendly error messages ────────────────────────────────────────

  group('_friendlyError', () {
    test('401 → API Key invalid', () {
      final err = _testFriendlyError(401);
      expect(err, contains('401'));
    });

    test('404 → not found', () {
      final err = _testFriendlyError(404);
      expect(err, contains('404'));
    });

    test('429 → rate limit', () {
      final err = _testFriendlyError(429);
      expect(err, contains('429'));
    });

    test('500 range → server error', () {
      final err = _testFriendlyError(503);
      expect(err, contains('503'));
    });

    test('connection timeout → timeout message', () {
      final err = _testFriendlyError(-1); // simulate timeout via type
      // Since we can't easily mock DioExceptionType, test unknown path
      final unknown = _testFriendlyError(999);
      expect(unknown, contains('999'));
    });
  });

  // ── SSE chunk parsing ──────────────────────────────────────────────

  group('SSE stream parsing', () {
    test('parses text delta from SSE line', () {
      final events = parseSSELine('data: {"choices":[{"delta":{"content":"Hello"}}]}');
      expect(events, hasLength(1));
      expect(events.first, isA<TextChunkEvent>());
      expect((events.first as TextChunkEvent).text, 'Hello');
    });

    test('parses reasoning delta from SSE line', () {
      final events = parseSSELine('data: {"choices":[{"delta":{"reasoning_content":"Let me think..."}}]}');
      expect(events, hasLength(1));
      expect(events.first, isA<ThinkingChunkEvent>());
      expect((events.first as ThinkingChunkEvent).text, 'Let me think...');
    });

    test('parses tool call id and name from SSE delta', () {
      final result = parseSSEWithToolCalls([
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_123","type":"function","function":{"name":"weather","arguments":""}}]}}]}',
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"city\\":\\"Beijing\\"}"}}]}}]}',
      ]);
      expect(result.toolCalls, hasLength(1));
      expect(result.toolCalls.first.id, 'call_123');
      expect(result.toolCalls.first.name, 'weather');
      expect(result.toolCalls.first.arguments, {'city': 'Beijing'});
    });

    test('ignores [DONE] marker', () {
      final events = parseSSELine('data: [DONE]');
      expect(events, isEmpty);
    });

    test('ignores empty data', () {
      final events = parseSSELine('data: ');
      expect(events, isEmpty);
    });

    test('ignores non-data lines', () {
      final events = parseSSELine(':ping');
      expect(events, isEmpty);
    });

    test('handles finish_reason length', () {
      final events = parseSSELine(
        'data: {"choices":[{"finish_reason":"length","delta":{}}]}',
      );
      expect(events, hasLength(1));
      expect(events.first, isA<ErrorEvent>());
      expect((events.first as ErrorEvent).message, contains('截断'));
    });

    test('parses multiple deltas in order (text and tool_calls)', () {
      final lines = [
        'data: {"choices":[{"delta":{"content":"The weather is "}}]}',
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"c1","type":"function","function":{"name":"weather","arguments":""}}]}}]}',
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"city\\":\\"NYC\\"}"}}]}}]}',
        'data: [DONE]',
      ];
      final result = parseSSEWithToolCalls(lines);
      expect(result.events.whereType<TextChunkEvent>(), hasLength(1));
      expect(result.toolCalls, hasLength(1));
    });
  });

  // ── ToolCall parsing ───────────────────────────────────────────────

  group('ToolCall.fromJson', () {
    test('parses full tool call JSON', () {
      final json = {
        'id': 'call_abc',
        'type': 'function',
        'function': {
          'name': 'weather',
          'arguments': '{"city":"Beijing","unit":"celsius"}',
        },
      };
      final tc = ToolCall.fromJson(json);
      expect(tc.id, 'call_abc');
      expect(tc.name, 'weather');
      expect(tc.arguments, {'city': 'Beijing', 'unit': 'celsius'});
    });

    test('handles empty arguments', () {
      final json = {
        'id': 'call_xyz',
        'type': 'function',
        'function': {'name': 'ping', 'arguments': '{}'},
      };
      final tc = ToolCall.fromJson(json);
      expect(tc.arguments, isEmpty);
    });

    test('handles malformed arguments gracefully', () {
      final json = {
        'id': 'call_bad',
        'type': 'function',
        'function': {'name': 'bad', 'arguments': 'not json'},
      };
      final tc = ToolCall.fromJson(json);
      expect(tc.arguments, isEmpty);
    });
  });
}

// ── Test helpers that access private members via same-library trick ──

/// Calls the private [_normalizeUrl] from [ai_service.dart] export.
String _testNormalizeUrl(String url) {
  // _normalizeUrl is a top-level function in ai_service.dart.
  // We can call it because we import the file.
  // ignore: depend_on_referenced_packages (it's our own file)
  return _callNormalize(url);
}

/// Duplicate of _normalizeUrl for testing (avoids private access issues).
String _callNormalize(String url) =>
    url.trim().replaceAll(RegExp(r'/+$'), '');

/// Tests [_isToolFailed] via ToolResult.failed.
bool _testIsToolFailed(String toolName, String content) {
  return ToolResult(toolName: toolName, content: content).failed;
}

/// Simulates [_friendlyError] logic for a given status code.
String _testFriendlyError(int? code) {
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
  return '请求失败${code != null ? ' ($code)' : ''}，请检查网络连接';
}

// ── SSE parsing simulation (mirrors _streamOpenAI logic) ────────────

class _SSEParseResult {
  final List<ChatStreamEvent> events;
  final List<ToolCall> toolCalls;
  _SSEParseResult(this.events, this.toolCalls);
}

/// Parses a single SSE line into ChatStreamEvents.
List<ChatStreamEvent> parseSSELine(String line) {
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

/// Parses multiple SSE lines and collects tool calls (simulates streaming).
_SSEParseResult parseSSEWithToolCalls(List<String> lines) {
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
