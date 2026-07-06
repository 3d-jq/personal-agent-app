import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 前台服务 - 保持应用在后台运行
class ForegroundService {
  static const _channel = MethodChannel('com.example/foreground_service');
  static bool _isRunning = false;
  static Timer? _heartbeatTimer;

  /// 启动前台服务
  static Future<void> start() async {
    if (_isRunning) return;
    
    try {
      // 初始化通知
      await _initNotifications();
      
      // 启动前台服务
      await _channel.invokeMethod('start', {
        'title': 'DWeis 正在运行',
        'message': '保持网络连接和消息推送',
      });
      
      _isRunning = true;
      
      // 启动心跳检测
      _startHeartbeat();
      
      debugPrint('前台服务已启动');
    } catch (e) {
      debugPrint('启动前台服务失败: $e');
    }
  }

  /// 停止前台服务
  static Future<void> stop() async {
    if (!_isRunning) return;
    
    try {
      _heartbeatTimer?.cancel();
      await _channel.invokeMethod('stop');
      _isRunning = false;
      debugPrint('前台服务已停止');
    } catch (e) {
      debugPrint('停止前台服务失败: $e');
    }
  }

  /// 初始化通知
  static Future<void> _initNotifications() async {
    final plugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
  }

  /// 启动心跳检测
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      // 心跳检测，保持服务活跃
      _channel.invokeMethod('heartbeat').catchError((_) {});
    });
  }

  /// 检查服务是否运行
  static bool get isRunning => _isRunning;
}
