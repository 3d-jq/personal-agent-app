import '../models/chat_message.dart';
import '../services/chat_storage.dart';

/// 消息分页窗口：负责视口滑动窗口的加载/翻页/游标管理。
///
/// 从 ChatController 中拆出，单一职责——只管消息的「取多少、何时翻页」，
/// 不关心流式、工具、压缩等。
///
/// 设计要点（性能铁律）：
/// - UI 列表**永远只渲染 [windowSize] 条**（一个固定窗口页），无论会话多长，屏幕
///   上气泡数量恒为 [windowSize]，从而把列表滚动/重绘开销锁死在常量级。
/// - [_messages] 持有「已加载范围」的**全量**内存副本（首屏取尾部 [windowSize]、
///   往上翻累加到前面、往下翻累加到后面、流式 append 到末尾），用于持久化
///   ([ChatController.saveSession] 增量 upsert) 与模型上下文（[ChatController.buildSendView]
///   走 DB 全量）——二者都不依赖本窗口，[windowSize] 与模型上下文彻底解耦。
/// - 翻页 = 在 [_messages] 上移动游标 [_windowStart]（纯内存 O(1)），只有越过已加载
///   边界（[_allOlderLoaded]/[_allNewerLoaded] 为假）才查一次 DB。
/// - 流式新消息：停在最新页时窗口自动跟随最新（滑动窗口）；停历史页时不打断当前阅读
///   （新消息进 [_messages] 但不进当前窗口页，靠 [hasNewer] 提示）。
class MessageWindow {
  final ChatStorage _storage;
  final List<ChatMessage> _messages;
  final void Function() _onChanged;

  String? _sessionId;

  int _nextSeq = 0;
  int _windowStart = 0;
  bool _allOlderLoaded = true;
  bool _allNewerLoaded = true;

  MessageWindow(this._storage, this._messages, this._onChanged);

  /// UI 视口窗口大小：仅决定「界面显示多少条」以节省性能，**与模型上下文无关**。
  /// 模型上下文由 [ChatController] 的发送视图单独取全量历史构造（见
  /// ChatController.buildSendView），从而能按 80% 阈值触发压缩。20 是纯 UI 调优值
  /// （界面显示条数，越小越省内存/滚动），不参与、也不影响大模型的上下文窗口——
  /// 切勿把它当成模型数据源。
  static const int windowSize = 20;
  /// 翻页大小：上滑/下滑一次加载的条数。
  static const int pageSize = 20;

  // ── Getters ──

  /// 当前窗口页（UI 列表数据源），长度恒为 [windowSize]（短会话可能更少）。
  List<ChatMessage> get visible {
    if (_messages.isEmpty) return const [];
    final start = _windowStart.clamp(0, _messages.length);
    final end = (start + windowSize).clamp(0, _messages.length);
    if (end <= start) return const [];
    return _messages.sublist(start, end);
  }

  /// 是否还能往上翻（加载更早的消息）。
  bool get hasOlder =>
      _sessionId != null &&
      _messages.isNotEmpty &&
      (_windowStart > 0 || !_allOlderLoaded);

  /// 是否还能往下翻（加载更新的消息）。
  bool get hasNewer =>
      _sessionId != null &&
      _messages.isNotEmpty &&
      (_windowStart + windowSize < _messages.length || !_allNewerLoaded);

  /// 是否应渲染翻页控件（会话有消息且在会话内）。
  bool get canPage => _sessionId != null && _messages.isNotEmpty;

  int get nextSeq => _nextSeq;

  // ── Session ──

  void bindSession(String id) {
    _sessionId = id;
  }

  /// 重置窗口（切会话/新建时调用）
  void reset() {
    _sessionId = null;
    _nextSeq = 0;
    _windowStart = 0;
    _allOlderLoaded = true;
    _allNewerLoaded = true;
    _messages.clear();
  }

  // ── Loading ──

  /// 首次加载窗口（尾部最新 [windowSize] 条）
  Future<void> load() async {
    final id = _sessionId;
    if (id == null) return;
    final session = await _storage.loadSession(id, limit: windowSize);
    _messages.clear();
    if (session != null) {
      _messages.addAll(session.messages);
    }
    _initState();
    // 初始窗口即尾部（最新 windowSize 条）：「较早消息」是否存在需结合 DB 总数判断，
    // 窗口恰好等于总数这一边界不能仅用「长度 < windowSize」判定（否则总数为整数倍
    // 窗口时会误报还有更早消息）。「较新消息」必然已全部载入（取的就是尾部）。
    if (_messages.isNotEmpty && _sessionId != null) {
      final total = await _storage.countMessages(_sessionId!);
      _allOlderLoaded = total <= _messages.length;
    }
    _onChanged();
  }

  /// 全量历史（**无视** UI 视口窗口）：仅供构造发送给大模型的「全量上下文视图」使用。
  ///
  /// 与 [windowSize] 彻底解耦——UI 只加载显示 [windowSize] 条以省性能，但模型必须
  /// 看到**全部**历史，才能按 80% 阈值触发 [HistoryManager] 压缩。绝不要用它填充 UI 列表。
  Future<List<ChatMessage>> loadFullHistory() async {
    final id = _sessionId;
    if (id == null) return const [];
    final session = await _storage.loadSession(id, full: true);
    return session?.messages ?? const [];
  }

  /// 上滑翻页：移动到更早的一页（在已加载范围内纯移动游标；越过边界才查 DB）。
  Future<void> loadOlder() async {
    if (_sessionId == null || _messages.isEmpty) return;
    // 已加载的更老页还在内存 → 纯游标移动（O(1)，零 DB 查询）
    if (_windowStart > 0) {
      _windowStart = (_windowStart - pageSize).clamp(0, _messages.length);
      _onChanged();
      return;
    }
    if (_allOlderLoaded) return;
    try {
      final oldestSeq = _messages[_windowStart].seq;
      final older = await _storage.loadSession(
        _sessionId!,
        limit: pageSize,
        beforeSeq: oldestSeq,
      );
      if (older == null || older.messages.isEmpty) {
        _allOlderLoaded = true;
      } else {
        // 新页插入到最前，窗口页即显示它（_windowStart 保持 0）
        _messages.insertAll(0, older.messages);
        _allOlderLoaded = older.messages.length < pageSize;
      }
    } finally {
      _onChanged();
    }
  }

  /// 下滑翻页：移动到更新的一页（在已加载范围内纯移动游标；越过边界才查 DB）。
  Future<void> loadNewer() async {
    if (_sessionId == null || _messages.isEmpty) return;
    final maxStart = (_messages.length - windowSize).clamp(0, _messages.length);
    // 已加载的更新页还在内存 → 纯游标移动（O(1)，零 DB 查询）
    if (_windowStart < maxStart) {
      _windowStart = (_windowStart + pageSize).clamp(0, maxStart);
      _onChanged();
      return;
    }
    if (_allNewerLoaded) return;
    try {
      final newestSeq = _messages[_windowStart + windowSize - 1].seq;
      final newer = await _storage.loadSession(
        _sessionId!,
        limit: pageSize,
        afterSeq: newestSeq,
      );
      if (newer == null || newer.messages.isEmpty) {
        _allNewerLoaded = true;
      } else {
        // 新页追加到末尾，窗口页移动到新页起点
        _messages.insertAll(_windowStart + windowSize, newer.messages);
        _windowStart = (_windowStart + windowSize).clamp(0, _messages.length);
        _allNewerLoaded = newer.messages.length < pageSize;
      }
    } finally {
      _onChanged();
    }
  }

  /// 一直翻到最新页（供「n 条新消息」浮条一键到达底部）。
  Future<void> jumpToLatestPage() async {
    while (hasNewer) {
      await loadNewer();
    }
  }

  /// 追加新消息并分配全局序号。
  ///
  /// 若当前停在最新页，窗口自动跟随最新（滑动窗口，始终保持 [windowSize] 条、
  /// 最新消息可见）；若停在历史页，新消息进 [_messages] 但不进当前窗口页
  /// （不打断阅读，靠 [hasNewer] 提示）。
  void append(ChatMessage msg) {
    final wasAtLatest =
        _windowStart >= (_messages.length - windowSize).clamp(0, _messages.length);
    msg.seq = _nextSeq++;
    _messages.add(msg);
    if (wasAtLatest) {
      _windowStart = (_messages.length - windowSize).clamp(0, _messages.length);
    }
  }

  // ── Internal ──

  void _initState() {
    if (_messages.isEmpty) {
      _nextSeq = 0;
      _windowStart = 0;
    } else {
      _nextSeq = _messages.last.seq + 1;
      _windowStart = (_messages.length - windowSize).clamp(0, _messages.length);
    }
    // 初始窗口即尾部（最新 windowSize 条），必然已是最新页
    _allNewerLoaded = true;
  }
}
