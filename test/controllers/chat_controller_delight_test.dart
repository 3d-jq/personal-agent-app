import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/controllers/chat_controller.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/models/chat_session.dart';
import 'package:personal_agent_app/services/chat_storage.dart';
import 'package:personal_agent_app/services/storage/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    await resetDependencies();
    await AppDatabase.instance.initializeForTest(databaseFactoryFfi);
    await configureDependencies();
  });

  tearDown(() async => await resetDependencies());

  group('ChatController message actions', () {
    test('deleteMessage removes the message and persists', () async {
      final m1 = ChatMessage(text: '你好', isUser: true);
      final m2 = ChatMessage(text: '我是 DWeis', isUser: false);
      final session = ChatSession(
        id: 's1',
        title: 't',
        messages: [m1, m2],
        updatedAt: DateTime(2025),
      );
      final fake = _FakeChatStorage()..sessions = [session];

      final controller = ChatController(chatStorage: fake);
      await controller.loadSession('s1');
      expect(controller.messages.length, 2);

      await controller.deleteMessage(m2);
      expect(controller.messages.length, 1);
      expect(controller.messages.first, m1);

      // 已持久化到存储
      expect(fake.sessions.first.messages.length, 1);
    });

    test('deleteMessage is a no-op for unknown message', () async {
      final m1 = ChatMessage(text: '你好', isUser: true);
      final session = ChatSession(
        id: 's1',
        title: 't',
        messages: [m1],
        updatedAt: DateTime(2025),
      );
      final fake = _FakeChatStorage()..sessions = [session];

      final controller = ChatController(chatStorage: fake);
      await controller.loadSession('s1');

      await controller.deleteMessage(ChatMessage(text: 'ghost', isUser: false));
      expect(controller.messages.length, 1);
    });
  });
}

class _FakeChatStorage implements ChatStorage {
  List<ChatSession> sessions = [];

  @override
  void clearCache() {}

  @override
  Future<void> delete(String id) async {
    sessions.removeWhere((s) => s.id == id);
  }

  @override
  Future<List<ChatSession>> loadAll({int? limit, int? offset}) async =>
      sessions;

  @override
  Future<List<ChatSession>> loadChatSessions({int? limit, int? offset}) async =>
      sessions;

  @override
  Future<ChatSession?> loadSession(String id,
      {int? afterSeq, int? limit, int? beforeSeq, bool full = false}) async {
    return sessions.where((s) => s.id == id).firstOrNull;
  }

  @override
  Future<void> save(ChatSession session) async {
    final idx = sessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      sessions[idx] = session;
    } else {
      sessions.add(session);
    }
  }

  @override
  Future<int> countMessages(String sessionId) async => 0;

  @override
  Future<void> deleteMessage(String sessionId, String msgId) async {}
}
