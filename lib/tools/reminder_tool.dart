import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/reminder.dart';
import '../services/reminder_storage.dart';
import '../tools/base_tool.dart';

@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {
  // Handle notification tap
}

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

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Set local timezone
    try {
      final localName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Fallback to UTC if local timezone not found
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidSettings,
    );
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'agent_reminders',
      'Agent 提醒',
      description: 'Agent 创建的定时提醒',
      importance: Importance.max,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request notification permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request exact alarms permission (Android 14+)
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    _initialized = true;
  }

  Future<bool> _checkAndRequestPermission() async {
    var status = await Permission.notification.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      status = await Permission.notification.request();
    }
    return status.isGranted;
  }

  static Future<void> cancelReminder(String id) async {
    await _plugin.cancel(id: id.hashCode);
    await ReminderStorage().remove(id);
  }

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    await _ensureInitialized();

    final hasPermission = await _checkAndRequestPermission();
    if (!hasPermission) {
      return '通知权限未开启，无法创建提醒。请在系统设置中允许 DWeis 发送通知。';
    }

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
      final id = const Uuid().v4();
      final notificationId = id.hashCode;
      final scheduledTime = tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds.toInt()));

      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'agent_reminders',
          'Agent 提醒',
          channelDescription: 'Agent 创建的定时提醒',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      );

      // For very short delays (< 60 seconds), use immediate notification
      if (delaySeconds.toInt() < 60) {
        await _plugin.show(
          id: notificationId,
          title: title,
          body: message,
          notificationDetails: notificationDetails,
        );
      } else {
        // For longer delays, use scheduled notification
        await _plugin.zonedSchedule(
          id: notificationId,
          title: title,
          body: message,
          scheduledDate: scheduledTime,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }

      final reminder = Reminder(
        id: id,
        title: title,
        message: message,
        scheduledTime: scheduledTime.toLocal(),
      );
      await ReminderStorage().add(reminder);

      final minutes = delaySeconds ~/ 60;
      final seconds = delaySeconds.toInt() % 60;
      return '已创建提醒: $title\n内容: $message\n将在 ${minutes > 0 ? '${minutes}分钟' : ''}${seconds > 0 ? '${seconds}秒' : ''}后推送';
    } catch (e) {
      return '创建提醒失败: $e';
    }
  }
}
