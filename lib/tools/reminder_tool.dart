import 'dart:io';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/reminder.dart';
import '../services/reminder_storage.dart';
import '../tools/base_tool.dart';

class ReminderTool extends AgentTool {
  @override String get name => 'reminder';
  @override bool get readOnly => false;

  @override
  String get description => '创建定时提醒，到时间会推送系统通知。当用户说"提醒我..."、"N分钟后叫我"、"定时提醒"时使用。';

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
        'type': 'number',
        'description': '延迟秒数。例如: 60=1分钟, 300=5分钟, 600=10分钟, 3600=1小时',
      },
      'delay_minutes': {
        'type': 'number',
        'description': '延迟分钟数（如果delay_seconds不好算，用这个）。例如: 1, 5, 10, 30, 60',
      },
    },
    'required': ['title', 'message'],
  };

  static bool _channelCreated = false;

  Future<void> _ensureChannel() async {
    if (_channelCreated) return;
    final plugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(settings: const InitializationSettings(android: android));
    const channel = AndroidNotificationChannel(
      'agent_reminders', 'Agent 提醒',
      description: 'Agent 创建的定时提醒',
      importance: Importance.max,
    );
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _channelCreated = true;
  }

  Future<String> _checkExactAlarmPermission() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return 'ok';
      final granted = await android.requestExactAlarmsPermission();
      if (granted == false) {
        return '精确闹钟权限未开启。请在 系统设置 → 应用 → DWeis → 权限 中开启「闹钟和提醒」权限，然后重试。';
      }
      return 'ok';
    } catch (e) {
      return '检查精确闹钟权限失败: $e';
    }
  }

  Future<bool> _checkNotificationPermission() async {
    var status = await Permission.notification.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      status = await Permission.notification.request();
    }
    return status.isGranted;
  }

  static Future<void> cancelReminder(String id) async {
    final nativeChannel = const MethodChannel('com.example/reminder');
    await nativeChannel.invokeMethod('cancel', {'id': id.hashCode.abs()});
    await ReminderStorage().remove(id);
  }

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    await _ensureChannel();

    final hasNotifPerm = await _checkNotificationPermission();
    if (!hasNotifPerm) {
      return '通知权限未开启，无法创建提醒。请在系统设置中允许 DWeis 发送通知。';
    }

    final alarmCheck = await _checkExactAlarmPermission();
    if (alarmCheck != 'ok') return alarmCheck;

    final title = args['title'] as String?;
    final message = args['message'] as String?;
    final delaySecondsRaw = args['delay_seconds'];
    final delayMinutesRaw = args['delay_minutes'];

    if (title == null || message == null) return '错误: 请提供提醒标题和内容';

    int delaySeconds;
    if (delayMinutesRaw != null && (delayMinutesRaw is num) && delayMinutesRaw > 0) {
      delaySeconds = (delayMinutesRaw.toDouble() * 60).toInt();
    } else if (delaySecondsRaw != null && (delaySecondsRaw is num) && delaySecondsRaw > 0) {
      delaySeconds = delaySecondsRaw.toInt();
    } else {
      return '错误: 延迟时间必须大于0。请提供 delay_seconds（秒）或 delay_minutes（分钟）';
    }
    if (delaySeconds > 86400) return '提醒时间不能超过24小时';

    try {
      final id = const Uuid().v4();
      final notificationId = id.hashCode.abs();

      final nativeChannel = const MethodChannel('com.example/reminder');
      await nativeChannel.invokeMethod('schedule', {
        'id': notificationId,
        'title': title,
        'message': message,
        'delaySeconds': delaySeconds,
      });

      await ReminderStorage().add(Reminder(
        id: id,
        title: title,
        message: message,
        scheduledTime: DateTime.now().add(Duration(seconds: delaySeconds)),
      ));

      final minutes = delaySeconds ~/ 60;
      final seconds = delaySeconds % 60;
      return '已创建提醒: $title\n内容: $message\n将在 ${minutes > 0 ? '${minutes}分钟' : ''}${seconds > 0 ? '${seconds}秒' : ''}后推送';
    } catch (e) {
      return '创建提醒失败: $e';
    }
  }
}
