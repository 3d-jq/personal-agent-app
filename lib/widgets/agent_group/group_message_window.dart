/// 群聊长会话分页窗口：始终只渲染末尾 [pageSize] 条，向上可加载更早。
///
/// 把 [GroupChatController] 里「_windowStart / _pageSize / loadEarlierPage /
/// ensureTailVisible」这套分页状态与翻页逻辑收拢到此，控制器只持有实例并委托。
class GroupMessageWindow {
  static const int pageSize = 30;
  int _start = 0;

  int get start => _start;
  bool get hasEarlier => _start > 0;

  /// 会话加载 / 新消息到达后，窗口重新对齐到末尾 [pageSize] 条。
  void reset(int messageCount) {
    _start = messageCount > pageSize ? messageCount - pageSize : 0;
  }

  /// 加载更早的消息：窗口向前提一页（滚动位置保持由页面 anchor 负责）。
  void loadEarlierPage() {
    if (_start <= 0) return;
    _start = _start > pageSize ? _start - pageSize : 0;
  }

  /// 保证窗口末尾对齐最新消息（活跃讨论时始终显示最新）。
  void ensureTailVisible(int messageCount) {
    _start = messageCount > pageSize ? messageCount - pageSize : 0;
  }
}
