import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../tools/base_tool.dart';

class ReminderTool extends AgentTool {
  @override
  String get name => 'reminder';

  @override
  String get description => '创建定时提醒。当用户需要在特定时间收到通知时使用。支持相对时间(如"10分钟后")和绝对时间(如"明天早上9点")。提醒会作为系统通知推送。';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'title': {
        'type': 'string',
        'description': '提醒标题',
      },
      'message': {
        'type': 'string',
        'description': '提醒内容',
      },
      'delay_seconds': {
        'type': 'integer',
        'description': '延迟多少秒后提醒。例如: 600=10分钟后, 3600=1小时后',
      },
    },
    'required': ['title', 'message', 'delay_seconds'],
  };

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _nextId = 1;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    _initialized = true;
  }

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    await _ensureInitialized();

    final title = args['title'] as String?;
    final message = args['message'] as String?;
    final delaySeconds = args['delay_seconds'] as num?;

    if (title == null || message == null) {
      return '错误: 请提供提醒标题和内容';
    }
    if (delaySeconds == null || delaySeconds <= 0) {
      return '错误: 延迟时间必须大于0';
    }
    if (delaySeconds > 86400) {
      return '提醒时间不能超过24小时';
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'agent_reminders',
        'Agent 提醒',
        channelDescription: 'Agent 创建的定时提醒',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);

      await _plugin.zonedSchedule(
        _nextId++,
        title,
        message,
        tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds.toInt())),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      final minutes = delaySeconds ~/ 60;
      final seconds = delaySeconds.toInt() % 60;
      return '已创建提醒: $title\n内容: $message\n将在 ${minutes > 0 ? '${minutes}分钟' : ''}${seconds > 0 ? '${seconds}秒' : ''}后推送';
    } catch (e) {
      return '创建提醒失败: $e';
    }
  }
}
