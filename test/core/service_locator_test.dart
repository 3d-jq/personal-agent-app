import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/services/agent_group_storage.dart';
import 'package:personal_agent_app/services/agent_storage.dart';
import 'package:personal_agent_app/models/chat_session.dart';
import 'package:personal_agent_app/services/chat_storage.dart';
import 'package:personal_agent_app/services/connectivity_service.dart';
import 'package:personal_agent_app/services/context_doc_service.dart';
import 'package:personal_agent_app/services/export_service.dart';
import 'package:personal_agent_app/services/media_storage.dart';
import 'package:personal_agent_app/services/notification_service.dart';
import 'package:personal_agent_app/services/note_storage.dart';
import 'package:personal_agent_app/services/reminder_storage.dart';
import 'package:personal_agent_app/services/theme_service.dart';
import 'package:personal_agent_app/services/virtual_fs.dart';
import 'package:personal_agent_app/tools/skill_registry.dart';
import 'package:personal_agent_app/widgets/ai_settings_sheet.dart';

void main() {
  setUp(() async {
    await resetDependencies();
    await configureDependencies();
  });

  tearDown(() async => await resetDependencies());

  group('ServiceLocator', () {
    test('registers all core services', () {
      expect(getIt.isRegistered<AgentStorage>(), true);
      expect(getIt.isRegistered<AgentGroupStorage>(), true);
      expect(getIt.isRegistered<ChatStorage>(), true);
      expect(getIt.isRegistered<ConnectivityService>(), true);
      expect(getIt.isRegistered<ContextDocService>(), true);
      expect(getIt.isRegistered<ExportService>(), true);
      expect(getIt.isRegistered<MediaStorage>(), true);
      expect(getIt.isRegistered<NotificationService>(), true);
      expect(getIt.isRegistered<NoteStorage>(), true);
      expect(getIt.isRegistered<ReminderStorage>(), true);
      expect(getIt.isRegistered<ThemeService>(), true);
      expect(getIt.isRegistered<VirtualFileSystem>(), true);
      expect(getIt.isRegistered<AISettings>(), true);
      expect(getIt.isRegistered<SkillRegistry>(), true);
    });

    test('returns the same singleton instance', () {
      final a = getIt<ChatStorage>();
      final b = getIt<ChatStorage>();
      expect(identical(a, b), true);
    });

    test('reset clears all registrations', () async {
      await resetDependencies();
      expect(() => getIt<ChatStorage>(), throwsA(isA<StateError>()));
    });

    test('allows replacing a service with a fake', () async {
      final fake = _FakeChatStorage();
      await resetDependencies();
      getIt.registerSingleton<ChatStorage>(fake);

      expect(getIt<ChatStorage>(), same(fake));
    });
  });
}

class _FakeChatStorage implements ChatStorage {
  @override
  void clearCache() {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<ChatSession>> loadAll() async => [];

  @override
  Future<List<ChatSession>> loadChatSessions() async => [];

  @override
  Future<ChatSession?> loadSession(String id,
          {int? limit, int? beforeSeq, bool full = false}) async =>
      null;

  @override
  Future<void> save(ChatSession session) async {}

  @override
  Future<int> countMessages(String sessionId) async => 0;

  @override
  Future<void> deleteMessage(String sessionId, String msgId) async {}
}
