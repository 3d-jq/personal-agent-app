import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/controllers/message_window.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/models/chat_session.dart';
import 'package:personal_agent_app/services/chat_storage.dart';

/// 构造 n 条消息，seq = 0..n-1（升序）。
List<ChatMessage> _makeStore(int n) => [
      for (int i = 0; i < n; i++)
        ChatMessage(text: 'm$i', isUser: false)..seq = i,
    ];

/// 存储中的总条数（用于计算「最近窗口」的起始 seq，避免硬编码窗口大小）。
const int _storeTotal = 100;

void main() {
  group('MessageWindow 游标窗口页（列表恒为 windowSize）', () {
    late FakeChatStorage storage;
    late List<ChatMessage> messages;
    late MessageWindow window;

    setUp(() {
      storage = FakeChatStorage()..store['s1'] = _makeStore(_storeTotal);
      messages = <ChatMessage>[];
      window = MessageWindow(storage, messages, () {});
    });

    test('load 加载尾部最新 windowSize 条；visible 恒为 windowSize，hasNewer=false',
        () async {
      window.bindSession('s1');
      await window.load();
      // 尾部最新 windowSize 条：seq (_storeTotal-windowSize)..(_storeTotal-1)
      expect(messages.length, MessageWindow.windowSize);
      expect(window.visible.length, MessageWindow.windowSize);
      expect(messages.first.seq, _storeTotal - MessageWindow.windowSize);
      expect(messages.last.seq, _storeTotal - 1);
      expect(window.hasOlder, isTrue); // 前面还有更早消息
      expect(window.hasNewer, isFalse); // 已是尾部最新页
      expect(window.canPage, isTrue);
    });

    test('hasOlder 边界：总数恰为窗口大小 → 没有更早消息', () async {
      storage.store['s1'] = _makeStore(MessageWindow.windowSize);
      window.bindSession('s1');
      await window.load();
      expect(window.visible.length, MessageWindow.windowSize);
      expect(window.hasOlder, isFalse);
      expect(window.hasNewer, isFalse);
    });

    test('hasOlder 边界：总数比窗口多 1 → 仍有更早消息', () async {
      storage.store['s1'] = _makeStore(MessageWindow.windowSize + 1);
      window.bindSession('s1');
      await window.load();
      expect(window.visible.length, MessageWindow.windowSize);
      expect(window.hasOlder, isTrue);
    });

    test('loadOlder 首次：去 DB 取更早一页并整体替换窗口页（列表长度仍恒为 windowSize）',
        () async {
      window.bindSession('s1');
      await window.load();
      await window.loadOlder();
      // 窗口页被替换为更老的一页：visible 仍是 windowSize 条（seq 60..79）
      expect(messages.length, MessageWindow.windowSize + MessageWindow.pageSize);
      expect(window.visible.length, MessageWindow.windowSize);
      expect(
        window.visible.first.seq,
        _storeTotal - MessageWindow.windowSize - MessageWindow.pageSize,
      );
      expect(
        window.visible.last.seq,
        _storeTotal - MessageWindow.windowSize - 1,
      );
      expect(window.hasOlder, isTrue);
    });

    test('连续 loadOlder 翻到最老页：visible 为 seq 0..windowSize-1，hasOlder 翻 false',
        () async {
      window.bindSession('s1');
      await window.load();
      while (window.hasOlder) {
        await window.loadOlder();
      }
      expect(messages.first.seq, 0);
      expect(messages.last.seq, _storeTotal - 1);
      expect(messages.length, _storeTotal);
      expect(window.visible.first.seq, 0);
      expect(window.visible.last.seq, MessageWindow.windowSize - 1);
      expect(window.hasOlder, isFalse);
    });

    test('从最老页 loadNewer 翻回最新页：visible 最终为尾部最新 windowSize 条',
        () async {
      window.bindSession('s1');
      await window.load();
      while (window.hasOlder) {
        await window.loadOlder();
      }
      // 现在停在最老页
      expect(window.visible.first.seq, 0);
      while (window.hasNewer) {
        await window.loadNewer();
      }
      expect(
        window.visible.first.seq,
        _storeTotal - MessageWindow.windowSize,
      );
      expect(window.visible.last.seq, _storeTotal - 1);
      expect(window.hasNewer, isFalse);
    });

    test('loadNewer 在已加载范围内纯移动游标（不查 DB，_messages 长度不变）',
        () async {
      window.bindSession('s1');
      await window.load();
      while (window.hasOlder) {
        await window.loadOlder();
      }
      await window.loadNewer(); // _windowStart 变 >0
      final lenBefore = messages.length;
      // 再 loadOlder：此时 _windowStart>0，应纯游标移动不查 DB
      await window.loadOlder();
      expect(messages.length, lenBefore); // 未新增（没查 DB）
      expect(window.visible.first.seq, 0); // 回到最老页
    });

    test('append 在最新页：窗口跟随最新（滑动，visible 长度恒为 windowSize，含新消息）',
        () async {
      window.bindSession('s1');
      await window.load(); // 最新页 seq 80..99，_windowStart=0（最新页）
      window.append(ChatMessage(text: 'new', isUser: false));
      expect(window.visible.length, MessageWindow.windowSize);
      expect(window.visible.last.text, 'new');
      expect(
        window.visible.first.seq,
        _storeTotal - MessageWindow.windowSize + 1,
      );
    });

    test('append 在历史页：新消息不进当前窗口页（不打断阅读），hasNewer 提示',
        () async {
      window.bindSession('s1');
      await window.load();
      await window.loadOlder(); // 翻到更老页（seq 60..79），仍在历史页
      final before = window.visible.first.seq;
      window.append(ChatMessage(text: 'new', isUser: false));
      // 当前窗口页不变（仍是历史页内容）
      expect(window.visible.first.seq, before);
      expect(window.hasNewer, isTrue); // 有新内容可翻
    });

    test('jumpToLatestPage：从最老页一键翻到最新页', () async {
      window.bindSession('s1');
      await window.load();
      while (window.hasOlder) {
        await window.loadOlder();
      }
      await window.jumpToLatestPage();
      expect(
        window.visible.first.seq,
        _storeTotal - MessageWindow.windowSize,
      );
      expect(window.visible.last.seq, _storeTotal - 1);
      expect(window.hasNewer, isFalse);
    });

    test('reset 复位游标与翻页标志（消息列表由调用方负责清空）', () async {
      window.bindSession('s1');
      await window.load();
      expect(window.hasOlder, isTrue);
      await window.loadOlder();
      expect(
        messages.length,
        MessageWindow.windowSize + MessageWindow.pageSize,
      );
      window.reset();
      expect(window.hasOlder, isFalse);
      expect(window.hasNewer, isFalse);
      expect(window.nextSeq, 0);
      // 重置后重新加载会从存储取回窗口（覆盖旧内容）
      window.bindSession('s1');
      await window.load();
      expect(messages.length, MessageWindow.windowSize);
      expect(
        messages.first.seq,
        _storeTotal - MessageWindow.windowSize,
      );
    });
  });
}

/// 脚本化存储：按 (beforeSeq / afterSeq / limit) 分页返回升序消息（与真实
/// [ChatStorage] 的「正序契约」一致：beforeSeq 取最接近的前 take 条、afterSeq
/// 取紧邻其后的前 take 条，均为升序）。
class FakeChatStorage implements ChatStorage {
  final Map<String, List<ChatMessage>> store = {};

  @override
  Future<ChatSession?> loadSession(
    String id, {
    int? afterSeq,
    int? limit,
    int? beforeSeq,
    bool full = false,
  }) async {
    final all = store[id] ?? <ChatMessage>[];
    List<ChatMessage> selected;
    if (beforeSeq != null) {
      final older = all.where((m) => m.seq < beforeSeq).toList();
      final take = limit ?? older.length;
      selected =
          older.length <= take ? older : older.sublist(older.length - take);
    } else if (afterSeq != null) {
      final newer = all.where((m) => m.seq > afterSeq).toList();
      final take = limit ?? newer.length;
      selected = newer.take(take).toList();
    } else {
      final take = limit ?? all.length;
      selected = all.length <= take ? all : all.sublist(all.length - take);
    }
    return ChatSession(
      id: id,
      title: '',
      messages: selected,
      updatedAt: DateTime(2025),
    );
  }

  @override
  void clearCache() {}

  @override
  Future<void> delete(String id) async => store.remove(id);

  @override
  Future<List<ChatSession>> loadAll({int? limit, int? offset}) async =>
      [for (final e in store.entries)
        ChatSession(id: e.key, title: '', messages: e.value, updatedAt: DateTime(2025))];

  @override
  Future<List<ChatSession>> loadChatSessions({int? limit, int? offset}) async =>
      [for (final e in store.entries)
        ChatSession(id: e.key, title: '', messages: e.value, updatedAt: DateTime(2025))];

  @override
  Future<void> save(ChatSession session) async {
    store[session.id] = session.messages;
  }

  @override
  Future<int> countMessages(String sessionId) async =>
      store[sessionId]?.length ?? 0;

  @override
  Future<void> deleteMessage(String sessionId, String msgId) async {}
}
