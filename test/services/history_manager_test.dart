import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/history_manager.dart';
import 'package:personal_agent_app/models/chat_message.dart';

void main() {
  group('HistoryManager', () {
    late HistoryManager manager;

    setUp(() {
      manager = const HistoryManager(
        contextWindowSize: 100000,
        maxOutputTokens: 4096,
        bufferTokens: 20000,
        keepTokens: 8000,
      );
    });

    group('estimateTokens', () {
      test('estimates Chinese text tokens', () {
        final tokens = HistoryManager.estimateTokens('你好世界');
        expect(tokens, greaterThan(0));
        expect(tokens, lessThanOrEqualTo(4)); // 4 chars / 2 = 2 tokens
      });

      test('estimates English text tokens', () {
        final tokens = HistoryManager.estimateTokens('Hello World');
        expect(tokens, greaterThan(0));
        expect(tokens, lessThanOrEqualTo(6)); // 11 chars / 4 ≈ 3 tokens
      });

      test('estimates mixed text tokens', () {
        final tokens = HistoryManager.estimateTokens('你好 Hello');
        expect(tokens, greaterThan(0));
      });
    });

    group('shouldCompress', () {
      test('returns false for empty messages', () {
        expect(manager.shouldCompress([]), false);
      });

      test('returns false for single message', () {
        final messages = [
          ChatMessage(text: 'Hello', isUser: true),
        ];
        expect(manager.shouldCompress(messages), false);
      });

      test('returns false for two messages', () {
        final messages = [
          ChatMessage(text: 'Hello', isUser: true),
          ChatMessage(text: 'Hi there', isUser: false),
        ];
        expect(manager.shouldCompress(messages), false);
      });

      test('returns false when under threshold', () {
        final messages = List.generate(
          5,
          (i) => ChatMessage(text: 'Message $i', isUser: i.isEven),
        );
        expect(manager.shouldCompress(messages), false);
      });

      test('returns true when over threshold', () {
        // Create messages that exceed context - buffer = 100000 - 20000 = 80000 tokens
        // Each message with ~1000 chars ≈ 250 tokens
        // Need 320+ messages to exceed 80000 tokens
        final messages = List.generate(
          400,
          (i) => ChatMessage(
            text: 'A' * 1000, // ~250 tokens per message
            isUser: i.isEven,
          ),
        );
        expect(manager.shouldCompress(messages), true);
      });
    });

    group('compressIfNeeded', () {
      test('returns original messages when no compression needed', () async {
        final messages = [
          ChatMessage(text: 'Hello', isUser: true),
          ChatMessage(text: 'Hi', isUser: false),
        ];

        final result = await manager.compressIfNeeded(
          messages,
          (msgs) async => 'Summary',
        );

        expect(identical(result, messages), true);
      });

      test('compresses messages when threshold exceeded', () async {
        // Create messages that exceed threshold
        // contextWindowSize=100000, bufferTokens=20000, so threshold=80000
        // Each message with ~2000 chars ≈ 500 tokens
        // Need 160+ messages to exceed 80000 tokens
        final messages = List.generate(
          200,
          (i) => ChatMessage(
            text: 'Message $i with some content to make it longer ' * 10,
            isUser: i.isEven,
          ),
        );

        final result = await manager.compressIfNeeded(
          messages,
          (msgs) async => '## Goal\n- Test summary\n## Progress\n- Done',
        );

        // Should have summary + recent messages (less than original)
        expect(result.length, lessThanOrEqualTo(messages.length));
        if (result.length < messages.length) {
          expect(result.first.text, contains('[历史摘要]'));
          expect(result.first.text, contains('Test summary'));
        }
      });

      test('keeps recent messages intact', () async {
        final messages = List.generate(
          400,
          (i) => ChatMessage(
            text: 'Message $i',
            isUser: i.isEven,
          ),
        );

        final result = await manager.compressIfNeeded(
          messages,
          (msgs) async => 'Summary',
        );

        // Last message should be preserved
        expect(result.last.text, messages.last.text);
      });

      test('skips compression when summary is empty', () async {
        final messages = List.generate(
          400,
          (i) => ChatMessage(text: 'Message $i', isUser: i.isEven),
        );

        final result = await manager.compressIfNeeded(
          messages,
          (msgs) async => '',
        );

        // Should return original messages
        expect(identical(result, messages), true);
      });
    });

    group('estimateMessagesTokens', () {
      test('estimates tokens for user message', () {
        final messages = [
          ChatMessage(text: 'Hello', isUser: true),
        ];
        final tokens = manager.estimateMessagesTokens(messages);
        expect(tokens, greaterThan(0));
      });

      test('estimates tokens for assistant message', () {
        final messages = [
          ChatMessage(text: 'Hi there', isUser: false),
        ];
        final tokens = manager.estimateMessagesTokens(messages);
        expect(tokens, greaterThan(0));
      });

      test('skips streaming messages', () {
        final messages = [
          ChatMessage(text: 'Hello', isUser: true),
          ChatMessage(text: 'Typing...', isUser: false, isStreaming: true),
        ];
        final tokens = manager.estimateMessagesTokens(messages);
        // Only first message should be counted
        expect(tokens, greaterThan(0));
      });
    });
  });
}
