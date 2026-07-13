import 'package:personal_agent_app/models/chat_session.dart';
import 'package:personal_agent_app/services/chat_storage.dart';

/// 可配置的 Fake ChatStorage，供测试共用。
///
/// 使用方式：构造时传入初始 [sessions]，可选 [loadDelay] 模拟 DB 加载耗时。
class FakeChatStorage implements ChatStorage {
  final List<ChatSession> sessions;
  final Duration? loadDelay;

  FakeChatStorage({List<ChatSession>? sessions, this.loadDelay})
      : sessions = sessions ?? [];

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
    if (loadDelay != null) await Future.delayed(loadDelay!);
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
