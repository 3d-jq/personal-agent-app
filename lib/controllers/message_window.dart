import '../models/chat_message.dart';
import '../services/chat_storage.dart';

/// 消息分页窗口：负责视口滑动窗口的加载/翻页/游标管理。
///
/// 从 ChatController 中拆出，单一职责——只管消息的「取多少、何时翻页」，
/// 不关心流式、工具、压缩等。
class MessageWindow {
  final ChatStorage _storage;
  final List<ChatMessage> _messages;
  final void Function() _onChanged;

  String? _sessionId;

  int _nextSeq = 0;
  int _oldestSeq = 0;
  bool _allOlderLoaded = true;
  bool _loadingOlder = false;

  MessageWindow(this._storage, this._messages, this._onChanged);

  /// UI 视口窗口大小：仅决定「界面首次加载并显示多少条」以节省性能，**与模型
  /// 上下文无关**。模型上下文由 [ChatController] 的发送视图单独取全量历史构造
  /// （见 ChatController.buildSendView），从而能按 80% 阈值触发压缩。20 是纯
  /// UI 调优值（首屏加载条数，越小越省内存/加载），不参与、也不影响大模型的上下文窗口——切勿把它当成模型数据源。
  static const int windowSize = 20;
  /// 翻页大小：上滑/下滑一次加载的条数。
  static const int pageSize = 20;

  // ── Getters ──

  bool get hasOlder => !_allOlderLoaded && _sessionId != null;
  int get nextSeq => _nextSeq;

  // ── Session ──

  void bindSession(String id) {
    _sessionId = id;
  }

  /// 重置窗口（切会话/新建时调用）
  void reset() {
    _sessionId = null;
    _nextSeq = 0;
    _oldestSeq = 0;
    _allOlderLoaded = true;
    _loadingOlder = false;
  }

  // ── Loading ──

  /// 首次加载窗口（20 条）
  Future<void> load() async {
    final id = _sessionId;
    if (id == null) return;
    final session = await _storage.loadSession(id, limit: windowSize);
    _messages.clear();
    if (session != null) {
      _messages.addAll(session.messages);
    }
    _initState();
    // load() 始终取尾部（最新 windowSize 条）窗口，因此「较新消息」必然已全部载入；
    // 「较早消息」是否存在需结合 DB 总数判断——窗口恰好等于总数这一边界不能仅用
    // 「长度 < windowSize」判定（否则总数为整数倍窗口时会误报还有更早消息）。
    if (_messages.isNotEmpty && _sessionId != null) {
      final total = await _storage.countMessages(_sessionId!);
      _allOlderLoaded = total <= _messages.length;
    }
    _onChanged();
  }

  /// 全量历史（**无视** UI 视口窗口）：仅供构造发送给大模型的「全量上下文视图」使用。
  ///
  /// 与 [windowSize] 彻底解耦——UI 只加载显示 20 条以省性能，但模型必须看到**全部**
  /// 历史，才能按 80% 阈值触发 [HistoryManager] 压缩。绝不要用它填充 UI 列表。
  Future<List<ChatMessage>> loadFullHistory() async {
    final id = _sessionId;
    if (id == null) return const [];
    final session = await _storage.loadSession(id, full: true);
    return session?.messages ?? const [];
  }

  /// 上滑翻页：加载更早的 20 条，prepend 到列表头
  Future<void> loadOlder() async {
    if (_allOlderLoaded || _loadingOlder || _sessionId == null || _messages.isEmpty) {
      return;
    }
    _loadingOlder = true;
    _onChanged();
    try {
      final older = await _storage.loadSession(
        _sessionId!,
        limit: pageSize,
        beforeSeq: _oldestSeq,
      );
      if (older == null || older.messages.isEmpty) {
        _allOlderLoaded = true;
      } else {
        _messages.insertAll(0, older.messages);
        _oldestSeq = _messages.first.seq;
        _allOlderLoaded = older.messages.length < pageSize;
      }
    } finally {
      _loadingOlder = false;
    }
    _onChanged();
  }

  /// 追加新消息并分配全局序号
  void append(ChatMessage msg) {
    msg.seq = _nextSeq++;
    _messages.add(msg);
  }

  // ── Internal ──

  void _initState() {
    if (_messages.isEmpty) {
      _nextSeq = 0;
      _oldestSeq = 0;
      _allOlderLoaded = true;
    } else {
      _nextSeq = _messages.last.seq + 1;
      _oldestSeq = _messages.first.seq;
      // 初始窗口即尾部（最新 windowSize 条），「较早消息」是否存在交由 load()
      // 结合 DB 总数校正；此处先保守置 false（假设还有更早消息），由 countMessages 判定。
      _allOlderLoaded = false;
    }
  }
}
