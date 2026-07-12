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

void main() {
  group('MessageWindow 视口滑动窗口', () {
    late _FakeChatStorage storage;
    late List<ChatMessage> messages;
    late MessageWindow window;

    setUp(() {
      storage = _FakeChatStorage()..store['s1'] = _makeStore(100);
      messages = <ChatMessage>[];
      window = MessageWindow(storage, messages, () {});
    });

    test('load 加载窗口内最近 40 条并据此设置游标', () async {
      window.bindSession('s1');
      await window.load();
      // 最近 40 条：seq 60..99
      expect(messages.length, 40);
      expect(messages.first.seq, 60);
      expect(messages.last.seq, 99);
      expect(window.hasOlder, isTrue);
    });

    test('loadOlder 上滑加载更早一页并 prepend 到列表头', () async {
      window.bindSession('s1');
      await window.load();
      await window.loadOlder();
      // 更早一页：seq 20..59，拼到 60..99 前
      expect(messages.length, 80);
      expect(messages.first.seq, 20);
      expect(messages.last.seq, 99);
    });

    test('连续 loadOlder 直到头部耗尽，hasOlder 翻 false', () async {
      window.bindSession('s1');
      await window.load();
      await window.loadOlder(); // 20..99
      await window.loadOlder(); // 0..99
      expect(messages.first.seq, 0);
      expect(messages.last.seq, 99);
      expect(window.hasOlder, isFalse);
      // 再翻页应为空操作，不报错、不重复
      await window.loadOlder();
      expect(messages.first.seq, 0);
      expect(messages.length, 100);
    });

    test('loadNewer 下滑加载较新一页（存储中已有窗口外的新消息）', () async {
      // 初始窗口只装下 0..39
      storage.store['s1'] = _makeStore(40);
      window.bindSession('s1');
      await window.load();
      expect(messages.last.seq, 39);

      // 存储中后续追加了 40..99，但窗口还没拉取
      storage.store['s1'] = _makeStore(100);
      await window.loadNewer(); // afterSeq=39 → 拉 seq 40..79
      expect(messages.length, 80);
      expect(messages.last.seq, 79);
      expect(window.hasNewer, isTrue);

      await window.loadNewer(); // afterSeq=79 → 拉 seq 80..99
      expect(messages.last.seq, 99);
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
      expect(messages.length, 80);
      window.reset();
      // 窗口状态复位
      expect(window.hasOlder, isFalse);
      expect(window.hasNewer, isFalse);
      expect(window.nextSeq, 0);
      // 重置后重新加载会从存储取回窗口（覆盖旧内容）
      window.bindSession('s1');
      await window.load();
      expect(messages.length, 40);
      expect(messages.first.seq, 60);
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
      [for (final e in store.entries) ChatSession(id: e.key, title: '', messages: e.value, updatedAt: DateTime(2025))];

  @override
  Future<List<ChatSession>> loadChatSessions({int? limit, int? offset}) async =>
      [for (final e in store.entries) ChatSession(id: e.key, title: '', messages: e.value, updatedAt: DateTime(2025))];

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
