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
  group('MessageWindow 视口滑动窗口', () {
    late _FakeChatStorage storage;
    late List<ChatMessage> messages;
    late MessageWindow window;

    setUp(() {
      storage = _FakeChatStorage()..store['s1'] = _makeStore(_storeTotal);
      messages = <ChatMessage>[];
      window = MessageWindow(storage, messages, () {});
    });

    test('load 加载窗口内最近 windowSize 条并据此设置游标', () async {
      window.bindSession('s1');
      await window.load();
      // 最近 windowSize 条：seq (_storeTotal-windowSize)..(_storeTotal-1)
      expect(messages.length, MessageWindow.windowSize);
      expect(messages.first.seq, _storeTotal - MessageWindow.windowSize);
      expect(messages.last.seq, _storeTotal - 1);
      expect(window.hasOlder, isTrue);
    });

    test('loadOlder 上滑加载更早一页并 prepend 到列表头', () async {
      window.bindSession('s1');
      await window.load();
      await window.loadOlder();
      // 更早一页：prepend pageSize 条，总数 = windowSize + pageSize
      expect(messages.length, MessageWindow.windowSize + MessageWindow.pageSize);
      expect(messages.first.seq,
          _storeTotal - MessageWindow.windowSize - MessageWindow.pageSize);
      expect(messages.last.seq, _storeTotal - 1);
    });

    test('连续 loadOlder 直到头部耗尽，hasOlder 翻 false', () async {
      window.bindSession('s1');
      await window.load();
      // 反复翻页直到没有更早消息（不依赖具体窗口/页大小，避免硬编码页数）
      while (window.hasOlder) {
        await window.loadOlder();
      }
      expect(messages.first.seq, 0);
      expect(messages.last.seq, _storeTotal - 1);
      expect(window.hasOlder, isFalse);
      // 再翻页应为空操作，不报错、不重复
      await window.loadOlder();
      expect(messages.first.seq, 0);
      expect(messages.length, _storeTotal);
    });

    test('loadNewer 下滑加载较新一页（存储中已有窗口外的新消息）', () async {
      // 初始窗口只装下最近 windowSize 条（windowSize=30 时为 10..39）
      storage.store['s1'] = _makeStore(40);
      window.bindSession('s1');
      await window.load();
      expect(messages.last.seq, 39);

      // 存储中后续追加了 40..89（50 条，非 pageSize 整数倍），窗口尚未拉取；
      // 用非整数倍可验证「最后一次拉到不足一页 → hasNewer 翻 false」的边界
      // （代码对「恰好一页」保守保留 hasNewer=true，属标准分页 hasMore 行为）。
      const int newerTotal = 90;
      storage.store['s1'] = _makeStore(newerTotal);
      await window.loadNewer(); // afterSeq=39 → 拉 seq 40..(39+pageSize)
      expect(messages.length, MessageWindow.windowSize + MessageWindow.pageSize);
      expect(messages.last.seq, 39 + MessageWindow.pageSize);
      expect(window.hasNewer, isTrue);

      await window.loadNewer(); // 拉剩余 70..89（不足一页）
      expect(messages.last.seq, newerTotal - 1);
      expect(window.hasNewer, isFalse);
    });

    test('append 分配递增的全局序号并写入同一引用列表', () {
      final a = ChatMessage(text: 'a', isUser: true);
      final b = ChatMessage(text: 'b', isUser: false);
      window.append(a);
      window.append(b);
      expect(a.seq, 0);
      expect(b.seq, 1);
      expect(messages, [a, b]);
    });

    test('reset 复位游标与翻页标志（消息列表由调用方负责清空）', () async {
      window.bindSession('s1');
      await window.load();
      expect(window.hasOlder, isTrue);
      await window.loadOlder();
      expect(messages.length, MessageWindow.windowSize + MessageWindow.pageSize);
      window.reset();
      // 窗口状态复位
      expect(window.hasOlder, isFalse);
      expect(window.hasNewer, isFalse);
      expect(window.nextSeq, 0);
      // 重置后重新加载会从存储取回窗口（覆盖旧内容）
      window.bindSession('s1');
      await window.load();
      expect(messages.length, MessageWindow.windowSize);
      expect(messages.first.seq, _storeTotal - MessageWindow.windowSize);
    });
  });
}

/// 脚本化存储：按 (beforeSeq / afterSeq / limit) 分页返回升序消息。
class _FakeChatStorage implements ChatStorage {
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
