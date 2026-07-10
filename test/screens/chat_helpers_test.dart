import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/screens/chat_helpers.dart';

void main() {
  group('buildMessageHistory 时间注入（cache 稳定化）', () {
    test('now 非空时末尾追加当前时间 user 消息，且不污染 system', () {
      final messages = [
        ChatMessage(text: '你好', isUser: true),
        ChatMessage(text: '你好！', isUser: false),
      ];
      final history = buildMessageHistory(
        systemPrompt: 'SYS',
        messages: messages,
        now: DateTime(2026, 7, 9, 13, 44),
      );

      // system 始终恒定，不携带时间
      expect(history.first, {'role': 'system', 'content': 'SYS'});

      // 末尾追加一条当前时间消息
      final last = history.last;
      expect(last['role'], 'user');
      expect(last['content'], contains('当前时间：'));
      expect(last['content'], contains('2026'));
      expect(last['content'], contains('13:44'));
    });

    test('now 为 null 时不追加时间消息', () {
      final messages = [ChatMessage(text: '你好', isUser: true)];
      final history = buildMessageHistory(
        systemPrompt: 'SYS',
        messages: messages,
        now: null,
      );
      // system + 一条用户消息，无额外时间消息
      expect(history, hasLength(2));
      expect(history.last['role'], 'user');
      expect(history.last['content'], '你好');
    });
  });
}
