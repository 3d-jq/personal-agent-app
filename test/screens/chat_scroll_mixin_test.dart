import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/screens/chat_scroll_mixin.dart';

/// 测试用载体：把 ChatScrollMixin 挂到一个真实可滚动的 ListView 上，
/// 以便验证滚动监听与自动贴底逻辑（这些都是 mixin 的核心职责）。
class _Harness extends StatefulWidget {
  const _Harness({this.messages = const <ChatMessage>[]});

  final List<ChatMessage> messages;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with ChatScrollMixin {
  @override
  int get messageCount => widget.messages.length;

  @override
  ChatMessage? get lastMessage =>
      widget.messages.isEmpty ? null : widget.messages.last;

  @override
  List<ChatMessage> get allMessages => widget.messages;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(onScroll);
  }

  @override
  void dispose() {
    scrollController.removeListener(onScroll);
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: 200,
      itemBuilder: (_, i) => SizedBox(height: 50, child: Text('item $i')),
    );
  }
}

void main() {
  testWidgets('持有 ScrollController，初始不显示回底浮条', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Harness()));
    final state = tester.state<_HarnessState>(find.byType(_Harness));
    expect(state.scrollController, isA<ScrollController>());
    expect(state.showScrollBottom, isFalse);
    expect(state.userScrolledUp, isFalse);
  });

  testWidgets('drawerOpen 时 scrollDown 提前返回，不滚动、不改状态', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Harness()));
    final state = tester.state<_HarnessState>(find.byType(_Harness));
    state.drawerOpen = true;
    final offsetBefore = state.scrollController.offset;
    state.scrollDown();
    await tester.pump();
    expect(state.scrollController.offset, offsetBefore);
    state.drawerOpen = false;
  });

  testWidgets('onScroll 区分顶/底：远离底部显示浮条并标记已上滑', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Harness()));
    final state = tester.state<_HarnessState>(find.byType(_Harness));
    final max = state.scrollController.position.maxScrollExtent;

    // 滚到底
    state.scrollController.jumpTo(max);
    await tester.pump();
    expect(state.showScrollBottom, isFalse);
    expect(state.userScrolledUp, isFalse);

    // 滚到顶（远离底部）
    state.scrollController.jumpTo(0);
    await tester.pump();
    expect(state.showScrollBottom, isTrue);
    expect(state.userScrolledUp, isTrue);
    // 无消息时锚点为 -1 / 0（lastMessage 为 null）
    expect(state.anchorSeq, -1);
    expect(state.anchorLen, 0);
  });

  testWidgets('unreadCount：上滑后锚点同条流式变长计 1 条未读', (tester) async {
    final msg = ChatMessage(text: 'a', isUser: false, seq: 1);
    await tester.pumpWidget(MaterialApp(home: _Harness(messages: [msg])));
    final state = tester.state<_HarnessState>(find.byType(_Harness));
    // 先到底再回顶，制造滚动以触发 onScroll 记录锚点
    final max = state.scrollController.position.maxScrollExtent;
    state.scrollController.jumpTo(max);
    await tester.pump();
    state.scrollController.jumpTo(0);
    await tester.pump();
    expect(state.userScrolledUp, isTrue);
    expect(state.anchorSeq, 1);
    expect(state.anchorLen, 1);
    // 锚点那条流式变长 → 实时计 1 条未读（pump 足够时长让 200ms 节流 Timer flush，
    // 否则 fake_async 会在测试结束时报「Timer still pending」）
    msg.text = 'abcdef';
    await tester.pump(const Duration(milliseconds: 250));
    expect(state.unreadCount(), 1);
    // 用户未上滑时不计未读
    state.userScrolledUp = false;
    expect(state.unreadCount(), 0);
  });

  testWidgets('unreadCount：上滑后新增 seq 更大的消息按条数计未读', (tester) async {
    final m1 = ChatMessage(text: 'a', isUser: false, seq: 1);
    final msgs = [m1];
    await tester.pumpWidget(MaterialApp(home: _Harness(messages: msgs)));
    final state = tester.state<_HarnessState>(find.byType(_Harness));
    final max = state.scrollController.position.maxScrollExtent;
    state.scrollController.jumpTo(max);
    await tester.pump();
    state.scrollController.jumpTo(0);
    await tester.pump();
    // 上滑锚点 seq=1
    final m2 = ChatMessage(text: 'b', isUser: false, seq: 2);
    final m3 = ChatMessage(text: 'c', isUser: false, seq: 3);
    msgs
      ..add(m2)
      ..add(m3);
    expect(state.unreadCount(), 2);
  });

  testWidgets('jumpToLatest 复位已上滑状态并跳到最新消息', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Harness()));
    final state = tester.state<_HarnessState>(find.byType(_Harness));
    final max = state.scrollController.position.maxScrollExtent;

    // 先滚到底，再滚到顶制造「已读中断」（jumpTo 仅在 offset 变化时触发 onScroll）
    state.scrollController.jumpTo(max);
    await tester.pump();
    state.scrollController.jumpTo(0);
    await tester.pump();
    expect(state.userScrolledUp, isTrue);

    state.jumpToLatest();
    await tester.pump();
    expect(state.userScrolledUp, isFalse);
    expect(state.scrollController.offset, max);
    expect(state.showScrollBottom, isFalse);
  });
}
