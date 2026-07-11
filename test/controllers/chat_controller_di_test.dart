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

  group('estimatedContextTokens 流式翻转缓存失效', () {
    test('流式结束 isStreaming 翻 false 应触发重算并纳入 AI 回复', () async {
      final userMsg = ChatMessage(text: '你好', isUser: true);
      final aiMsg = ChatMessage(
        text: '这是一条较长的 AI 回复内容用于估算 token 占用',
        isUser: false,
        isStreaming: true,
      );
      final session = ChatSession(
        id: 's1',
        title: 'Test',
        messages: [userMsg, aiMsg],
        updatedAt: DateTime(2025, 1, 1),
      );
      final fake = _FakeChatStorage()..sessions = [session];

      final controller = ChatController(chatStorage: fake);
      await controller.loadSession('s1');

      // 流式进行中：AI 回复被跳过（isStreaming=true），仅计入用户消息
      final streamingTokens = controller.estimatedContextTokens;
      // 模拟流式收尾：仅翻转 isStreaming，文本长度不变
      aiMsg.isStreaming = false;
      final finalizedTokens = controller.estimatedContextTokens;

      // 翻转后必须纳入 AI 回复（否则会漏算整条回复 —— 问题 1 根因）
      expect(finalizedTokens, greaterThan(streamingTokens));
      expect(finalizedTokens - streamingTokens, greaterThan(0));
    });

    test('引用/条数/长度/流式状态均未变时复用缓存（无重复重算）', () async {
      final userMsg = ChatMessage(text: '你好世界', isUser: true);
      final aiMsg =
          ChatMessage(text: '已完成的回复', isUser: false, isStreaming: false);
      final session = ChatSession(
        id: 's1',
        title: 'Test',
        messages: [userMsg, aiMsg],
        updatedAt: DateTime(2025, 1, 1),
      );
      final fake = _FakeChatStorage()..sessions = [session];
      final controller = ChatController(chatStorage: fake);
      await controller.loadSession('s1');

      final first = controller.estimatedContextTokens;
      final second = controller.estimatedContextTokens;
      expect(second, first);
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
  Future<ChatSession?> loadSession(String id,
      {int? limit, int? beforeSeq, bool full = false}) async {
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
