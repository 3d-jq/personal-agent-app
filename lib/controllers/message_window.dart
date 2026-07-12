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
  int _newestSeq = 0;
  bool _allOlderLoaded = true;
  bool _allNewerLoaded = true;
  bool _loadingOlder = false;
  bool _loadingNewer = false;

  MessageWindow(this._storage, this._messages, this._onChanged);

  /// UI 视口窗口大小：仅决定「界面首次加载并显示多少条」以节省性能，**与模型
  /// 上下文无关**。模型上下文由 [ChatController] 的发送视图单独取全量历史构造
  /// （见 ChatController.buildSendView），从而能按 80% 阈值触发压缩。30 是纯
  /// UI 调优值（较 40 更省首屏加载），不参与、也不影响大模型的上下文窗口——切勿把它当成模型数据源。
  static const int windowSize = 30;
  /// 翻页大小：上滑/下滑一次加载的条数。
  static const int pageSize = 30;

  // ── Getters ──

  bool get hasOlder => !_allOlderLoaded && _sessionId != null;
  bool get hasNewer => !_allNewerLoaded && _sessionId != null;
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
    _newestSeq = 0;
    _allOlderLoaded = true;
    _allNewerLoaded = true;
    _loadingOlder = false;
    _loadingNewer = false;
  }

  // ── Loading ──

  /// 首次加载窗口（30 条）
  Future<void> load() async {
    final id = _sessionId;
    if (id == null) return;
    final session = await _storage.loadSession(id, limit: windowSize);
    _messages.clear();
    if (session != null) {
      _messages.addAll(session.messages);
    }
    _initState();
    _onChanged();
  }

  /// 全量历史（**无视** UI 视口窗口）：仅供构造发送给大模型的「全量上下文视图」使用。
  ///
  /// 与 [windowSize] 彻底解耦——UI 只加载显示 30 条以省性能，但模型必须看到**全部**
  /// 历史，才能按 80% 阈值触发 [HistoryManager] 压缩。绝不要用它填充 UI 列表。
  Future<List<ChatMessage>> loadFullHistory() async {
    final id = _sessionId;
    if (id == null) return const [];
    final session = await _storage.loadSession(id, full: true);
    return session?.messages ?? const [];
  }

  /// 上滑翻页：加载更早的 30 条，prepend 到列表头
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

  /// 下滑翻页：加载较新的 30 条，追加到列表尾
  Future<void> loadNewer() async {
    if (_allNewerLoaded || _loadingNewer || _sessionId == null || _messages.isEmpty) {
      return;
    }
    _loadingNewer = true;
    _onChanged();
    try {
      final newer = await _storage.loadSession(
        _sessionId!,
        limit: pageSize,
        afterSeq: _newestSeq,
      );
      if (newer == null || newer.messages.isEmpty) {
        _allNewerLoaded = true;
      } else {
        _messages.addAll(newer.messages);
        _newestSeq = _messages.last.seq;
        _nextSeq = _newestSeq + 1;
        _allNewerLoaded = newer.messages.length < pageSize;
      }
    } finally {
      _loadingNewer = false;
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
      _newestSeq = 0;
      _allOlderLoaded = true;
      _allNewerLoaded = true;
    } else {
      _nextSeq = _messages.last.seq + 1;
      _oldestSeq = _messages.first.seq;
      _newestSeq = _messages.last.seq;
      _allOlderLoaded = _messages.length < windowSize;
      _allNewerLoaded = _messages.length < windowSize;
    }
  }
}
