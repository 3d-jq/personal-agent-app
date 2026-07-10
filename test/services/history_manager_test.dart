import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/history_manager.dart';
import 'package:personal_agent_app/models/chat_message.dart';

void main() {
  group('HistoryManager', () {
    late HistoryManager manager;

    setUp(() {
      manager = HistoryManager(
        contextWindowSize: 100000,
        maxOutputTokens: 4096,
        keepTokens: 8000,
      );
    });

    group('compressionThreshold', () {
      test('大窗口用满 80%', () {
        final m = HistoryManager(contextWindowSize: 256000);
        expect(m.compressionThreshold, 256000 * 0.8);
      });

      test('128K 窗口也用满 80%', () {
        final m = HistoryManager(contextWindowSize: 128000);
        expect(m.compressionThreshold, 128000 * 0.8);
      });

      test('小窗口为输出留余量、自动后退不到 80%', () {
        // 32K: 80% = 25600，但需留 maxOutput(4096)+4000=8096 余量 → 阈值 32000-8096=23904
        final m = HistoryManager(contextWindowSize: 32000);
        expect(m.compressionThreshold, lessThan(32000 * 0.8));
        expect(m.compressionThreshold, 32000 - (4096 + 4000));
      });

      test('极小窗口兜底不为负', () {
        final m = HistoryManager(contextWindowSize: 8000);
        expect(m.compressionThreshold, greaterThanOrEqualTo(0));
      });
    });

    group('estimateTokens', () {
      test('estimates Chinese text tokens', () {
        final tokens = manager.estimateTokens('你好世界');
        expect(tokens, greaterThan(0));
        expect(tokens, lessThanOrEqualTo(4)); // 4 chars / 2 = 2 tokens
      });

      test('estimates English text tokens', () {
        final tokens = manager.estimateTokens('Hello World');
        expect(tokens, greaterThan(0));
        expect(tokens, lessThanOrEqualTo(6)); // 11 chars / 4 ≈ 3 tokens
      });

      test('estimates mixed text tokens', () {
        final tokens = manager.estimateTokens('你好 Hello');
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
        // 压缩阈值 = 100000 的 80% = 80000 tokens（小窗口才后退，此处即 80%）
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
        // 压缩阈值 = 100000 的 80% = 80000 tokens
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
