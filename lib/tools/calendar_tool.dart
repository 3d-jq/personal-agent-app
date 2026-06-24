import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../tools/base_tool.dart';
import 'calendar_tool.g.dart';

class CalendarTool extends AgentTool {
  @override
  String get name => 'calendar';
  @override
  bool get readOnly => false;

  @override
  String get description => calendarToolDescription;

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'description': '操作: query/add/delete',
        'enum': ['query', 'add', 'delete'],
      },
      'title': {'type': 'string', 'description': '事件标题（add）'},
      'description': {'type': 'string', 'description': '事件描述（可选）'},
      'start_ms': {'type': 'number', 'description': '开始毫秒时间戳'},
      'end_ms': {'type': 'number', 'description': '结束毫秒时间戳，默认开始后1小时'},
      'date': {
        'type': 'string',
        'description': '日期 YYYY-MM-DD，如 2026-06-15。优先使用此参数',
      },
      'time': {'type': 'string', 'description': '时间 HH:MM，如 10:00。默认 09:00'},
      'event_id': {'type': 'number', 'description': '事件ID（delete）'},
    },
    'required': ['action'],
  };

  static const _channel = MethodChannel('com.example/calendar');

  Future<bool> _ensurePerm() async {
    var s = await Permission.calendarFullAccess.status;
    if (s.isDenied || s.isPermanentlyDenied)
      s = await Permission.calendarFullAccess.request();
    return s.isGranted;
  }

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    if (!await _ensurePerm()) return '日历权限未开启，请在系统设置中允许 DWeis 访问日历。';
    final action = args['action'] as String?;
    if (action == null) return '错误: 请指定操作类型';
    try {
      switch (action) {
        case 'query':
          final s =
              (args['start_ms'] as num?)?.toInt() ??
              DateTime.now()
                  .subtract(const Duration(days: 1))
                  .millisecondsSinceEpoch
                  .toInt();
          final e =
              (args['end_ms'] as num?)?.toInt() ??
              DateTime.now()
                  .add(const Duration(days: 7))
                  .millisecondsSinceEpoch
                  .toInt();
          return await _channel.invokeMethod<String>('query', {
                'startMs': s,
                'endMs': e,
              }) ??
              '查询失败';
        case 'add':
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
            s =
                (args['start_ms'] as num?)?.toInt() ??
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
        case 'delete':
          final id = (args['event_id'] as num?)?.toInt();
          if (id == null) return '错误: 请提供事件ID';
          return await _channel.invokeMethod<String>('delete', {'id': id}) ??
              '删除失败';
        default:
          return '不支持的操作';
      }
    } catch (e) {
      return '日历操作失败: $e';
    }
  }
}
