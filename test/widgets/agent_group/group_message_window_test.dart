import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/widgets/agent_group/group_message_window.dart';

void main() {
  group('GroupMessageWindow 群聊分页窗口', () {
    test('pageSize 固定为 30', () {
      expect(GroupMessageWindow.pageSize, 30);
    });

    test('reset 在消息不足一页时窗口从 0 起始', () {
      final w = GroupMessageWindow();
      w.reset(10);
      expect(w.start, 0);
      expect(w.hasEarlier, isFalse);
    });

    test('reset 在消息超过一页时窗口对齐到末尾 30 条', () {
      final w = GroupMessageWindow();
      w.reset(50);
      expect(w.start, 20); // 50 - 30
      expect(w.hasEarlier, isTrue);
    });

    test('loadEarlierPage 向前提一页，到头部后停在 0', () {
      final w = GroupMessageWindow();
      w.reset(80); // start = 50
      expect(w.start, 50);
      w.loadEarlierPage();
      expect(w.start, 20); // 50 - 30
      w.loadEarlierPage();
      expect(w.start, 0); // 20 - 30 < 0 → 0
      // 已到头部，再翻页无操作
      w.loadEarlierPage();
      expect(w.start, 0);
      expect(w.hasEarlier, isFalse);
    });

    test('ensureTailVisible 始终把窗口对齐到最新消息', () {
      final w = GroupMessageWindow();
      w.loadEarlierPage(); // 无操作（start 仍为 0）
      w.ensureTailVisible(80);
      expect(w.start, 50); // 80 - 30
      w.ensureTailVisible(5);
      expect(w.start, 0); // 不足一页
    });
  });
}
