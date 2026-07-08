import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/controllers/chat_controller.dart';
import 'package:personal_agent_app/core/service_locator.dart';
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
  void clearCache() {}

  @override
  Future<void> delete(String id) async {
    sessions.removeWhere((s) => s.id == id);
  }

  @override
  Future<List<ChatSession>> loadAll() async => sessions;

  @override
  Future<List<ChatSession>> loadChatSessions() async => sessions;

  @override
  Future<ChatSession?> loadSession(String id) async {
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
}
