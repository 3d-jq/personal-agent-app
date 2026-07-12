import 'dart:collection';

/// 性能指标条目
class PerfEntry {
  final String tag;
  final String label;
  final String value;
  final DateTime time;

  const PerfEntry({
    required this.tag,
    required this.label,
    required this.value,
    required this.time,
  });
}

/// 轻量性能监控：
/// - 收集最近 N 条性能指标（缓存命中 / 工具耗时 / 压缩统计 / 流式耗时）
/// - 按 tag 分组，UI 可实时查阅
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._();

  static const _maxEntries = 200;
  final List<PerfEntry> _entries = [];
  final Set<void Function()> _listeners = {};

  UnmodifiableListView<PerfEntry> get entries =>
      UnmodifiableListView(_entries);

  List<PerfEntry> get latest => _entries.toList();

  void _emit(String tag, String label, String value) {
    _entries.add(PerfEntry(
      tag: tag,
      label: label,
      value: value,
      time: DateTime.now(),
    ));
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    for (final l in _listeners) {
      l();
    }
  }

  void addListener(void Function() cb) {
    _listeners.add(cb);
  }

  void removeListener(void Function() cb) {
    _listeners.remove(cb);
  }

  void clear() {
    _entries.clear();
    for (final l in _listeners) {
      l();
    }
  }

  // ── 记录入口 ──

  void cacheHit(String tag, String value) {
    _emit('cache', tag, value);
  }

  void toolTiming(String toolName, int ms) {
    _emit('tool', toolName, '${ms}ms');
  }

  void toolBatch(int count, int totalMs) {
    _emit('tool', '批次完成', '$count 个工具 / ${totalMs}ms');
  }

  void compression(String label, String value) {
    _emit('compress', label, value);
  }

  void summarize(String label, String value) {
    _emit('summarize', label, value);
  }

  void streamMetric(String label, String value) {
    _emit('stream', label, value);
  }

  // ── 分组查询 ──

  Map<String, List<PerfEntry>> grouped() {
    final map = <String, List<PerfEntry>>{};
    for (final e in _entries) {
      map.putIfAbsent(e.tag, () => []).add(e);
    }
    return map;
  }

  List<PerfEntry> byTag(String tag) {
    return _entries.where((e) => e.tag == tag).toList();
  }
}

typedef VoidCallback = void Function();

/// 全局实例
final perf = PerformanceMonitor();
