import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/controllers/chat_controller.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/models/chat_session.dart';
import 'package:personal_agent_app/services/chat_storage.dart';

void main() {
  setUp(() {
    resetDependencies();
    configureDependencies();
  });

  tearDown(resetDependencies);

  group('ChatController DI', () {
    test('uses injected ChatStorage when provided', () async {
      final fake = _FakeChatStorage()
        ..sessions = [
          ChatSession(
            id: 's1',
            title: 'Test',
            messages: [],
            updatedAt: DateTime(2025, 1, 1),
          ),
        ];

      final controller = ChatController(chatStorage: fake);
      await controller.refreshSessions();

      expect(controller.sessions.length, 1);
      expect(controller.sessions.first.id, 's1');
    });

    test('falls back to getIt<ChatStorage>() when none provided', () async {
      final controller = ChatController();

      expect(controller.sessions, isEmpty);
      expect(() => controller.refreshSessions(), returnsNormally);
    });
  });
}

class _FakeChatStorage implements ChatStorage {
  List<ChatSession> sessions = [];

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<ChatSession>> loadAll() async => sessions;

  @override
  Future<void> save(ChatSession session) async {
    sessions.add(session);
  }
}
