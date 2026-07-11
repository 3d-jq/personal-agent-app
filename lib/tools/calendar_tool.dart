import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../tools/base_tool.dart';
import 'calendar_query_tool.g.dart';
import 'calendar_add_tool.g.dart';
import 'calendar_delete_tool.g.dart';

/// 日历工具。
///
/// 原 `calendar`（带 action 参数）已拆分为 3 个独立工具，各自独占调用配额：
/// - [CalendarQueryTool] 查看日程
/// - [CalendarAddTool]   添加日程
/// - [CalendarDeleteTool] 删除日程
abstract class _CalendarBase extends AgentTool {
  static const _channel = MethodChannel('com.example/calendar');

  Future<bool> _ensurePerm() async {
    var s = await Permission.calendarFullAccess.status;
    if (s.isDenied || s.isPermanentlyDenied) {
      s = await Permission.calendarFullAccess.request();
    }
    return s.isGranted;
  }

  @override
  bool get readOnly => false;

  Future<String> query(Map<String, dynamic> args) async {
    final s = (args['start_ms'] as num?)?.toInt() ??
        DateTime.now()
            .subtract(const Duration(days: 1))
            .millisecondsSinceEpoch
            .toInt();
    final e = (args['end_ms'] as num?)?.toInt() ??
        DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch.toInt();
    return await _channel.invokeMethod<String>('query', {
          'startMs': s,
          'endMs': e,
        }) ??
        '查询失败';
  }

  Future<String> add(Map<String, dynamic> args) async {
    final t = args['title'] as String?;
    if (t == null || t.isEmpty) return '错误: 请提供事件标题';
    int s, e;
    final ds = args['date'] as String?;
    final ts = args['time'] as String?;
    if (ds != null && ds.isNotEmpty) {
      try {
        final dt = DateTime.parse('${ds}T${ts ?? '09:00'}:00');
        s = dt.millisecondsSinceEpoch;
        e = dt.add(const Duration(hours: 1)).millisecondsSinceEpoch;
      } catch (_) {
        return '日期格式错误，请用 YYYY-MM-DD，如 2026-06-15';
      }
    } else {
      s = (args['start_ms'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch.toInt();
      e = (args['end_ms'] as num?)?.toInt() ?? s + 3600000;
    }
    return await _channel.invokeMethod<String>('add', {
          'title': t,
          'description': args['description'] ?? '',
          'startMs': s,
          'endMs': e,
        }) ??
        '添加失败';
  }

  Future<String> remove(Map<String, dynamic> args) async {
    final id = (args['event_id'] as num?)?.toInt();
    if (id == null) return '错误: 请提供事件ID';
    return await _channel.invokeMethod<String>('delete', {'id': id}) ?? '删除失败';
  }
}

/// 查看一段时间内的日历日程。
class CalendarQueryTool extends _CalendarBase {
  @override
  String get name => 'calendar_query';
  @override
  String get description => calendarQueryToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'start_ms': {'type': 'number', 'description': '开始毫秒时间戳'},
      'end_ms': {'type': 'number', 'description': '结束毫秒时间戳，默认开始后7天'},
      'date': {
        'type': 'string',
        'description': '日期 YYYY-MM-DD，如 2026-06-15。优先使用此参数',
      },
      'time': {'type': 'string', 'description': '时间 HH:MM，如 10:00。默认 09:00'},
    },
    'required': <String>[],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    if (!await _ensurePerm()) return '日历权限未开启，请在系统设置中允许 DWeis 访问日历。';
    try {
      return await query(args);
    } catch (e) {
      return '日历操作失败: $e';
    }
  }
}

/// 添加一条日历日程。
class CalendarAddTool extends _CalendarBase {
  @override
  String get name => 'calendar_add';
  @override
  String get description => calendarAddToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'title': {'type': 'string', 'description': '事件标题'},
      'description': {'type': 'string', 'description': '事件描述（可选）'},
      'start_ms': {'type': 'number', 'description': '开始毫秒时间戳'},
      'end_ms': {'type': 'number', 'description': '结束毫秒时间戳，默认开始后1小时'},
      'date': {
        'type': 'string',
        'description': '日期 YYYY-MM-DD，如 2026-06-15。优先使用此参数',
      },
      'time': {'type': 'string', 'description': '时间 HH:MM，如 10:00。默认 09:00'},
    },
    'required': ['title'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    if (!await _ensurePerm()) return '日历权限未开启，请在系统设置中允许 DWeis 访问日历。';
    try {
      return await add(args);
    } catch (e) {
      return '日历操作失败: $e';
    }
  }
}

/// 删除一条日历日程。
class CalendarDeleteTool extends _CalendarBase {
  @override
  String get name => 'calendar_delete';
  @override
  String get description => calendarDeleteToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'event_id': {'type': 'number', 'description': '事件ID'},
    },
    'required': ['event_id'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    if (!await _ensurePerm()) return '日历权限未开启，请在系统设置中允许 DWeis 访问日历。';
    try {
      return await remove(args);
    } catch (e) {
      return '日历操作失败: $e';
    }
  }
}
