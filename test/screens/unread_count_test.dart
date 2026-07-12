import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/screens/chat_scroll_mixin.dart';

/// [computeUnreadCount] 是单聊/群聊共用的「n 条新消息」未读算法纯函数。
/// 这里集中覆盖其所有分支，避免双端各写一份逻辑、行为漂移。
void main() {
  group('computeUnreadCount', () {
    final base = [
      ChatMessage(text: 'a', isUser: false, seq: 1),
      ChatMessage(text: 'b', isUser: false, seq: 2),
    ];

    test('returns 0 when user not scrolled up', () {
      expect(computeUnreadCount(base, 2, 1, false), 0);
    });

    test('returns 0 for empty list even if scrolled up', () {
      expect(computeUnreadCount([], -1, 0, true), 0);
    });

    test('counts new messages with larger seq', () {
      final msgs = [
        ...base,
        ChatMessage(text: 'c', isUser: false, seq: 3),
        ChatMessage(text: 'd', isUser: false, seq: 4),
      ];
      // 锚点停在 seq=2（上滑那一刻见的最后一条）
      expect(computeUnreadCount(msgs, 2, 1, true), 2);
    });

    test('counts the anchored message still streaming as 1', () {
      // 上滑锚点 seq=2, len=1('b')；之后 'b' 流式变长到 'bxy'(len=3)
      final msgs = [
        ChatMessage(text: 'a', isUser: false, seq: 1),
        ChatMessage(text: 'bxy', isUser: false, seq: 2),
      ];
      expect(computeUnreadCount(msgs, 2, 1, true), 1);
    });

    test('does not double-count streaming when newer messages exist', () {
      final msgs = [
        ChatMessage(text: 'a', isUser: false, seq: 1),
        ChatMessage(text: 'bxy', isUser: false, seq: 2), // 锚点，也变长了
        ChatMessage(text: 'c', isUser: false, seq: 3),
      ];
      // seq>2 的只有 1 条(c)；count>0 时不再把锚点变长额外计 1
      expect(computeUnreadCount(msgs, 2, 1, true), 1);
    });

    test('counts multiple new messages', () {
      final msgs = [
        ...base,
        ChatMessage(text: 'c', isUser: false, seq: 3),
        ChatMessage(text: 'd', isUser: false, seq: 4),
        ChatMessage(text: 'e', isUser: false, seq: 5),
      ];
      expect(computeUnreadCount(msgs, 2, 1, true), 3);
    });
  });
}
