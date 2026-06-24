import 'package:flutter/services.dart';

class NotificationService {
  NotificationService();

  static const _channel = MethodChannel('com.example/live_activity');

  Future<void> startTask({
    required String id,
    required String title,
    required String message,
  }) async {
    await _call('startTask', {'id': id, 'title': title, 'message': message});
  }

  Future<void> updateMessage({
    required String id,
    required String message,
  }) async {
    await _call('updateMessage', {'id': id, 'message': message});
  }

  Future<void> updateProgress({
    required String id,
    required int progress,
    int maxProgress = 100,
    String? message,
  }) async {
    await _call('updateProgress', {
      'id': id,
      'progress': progress,
      'maxProgress': maxProgress,
      if (message != null) 'message': message,
    });
  }

  Future<void> complete({
    required String id,
    String? title,
    String? message,
  }) async {
    await _call('complete', {
      'id': id,
      if (title != null) 'title': title,
      if (message != null) 'message': message,
    });
  }

  Future<void> fail({
    required String id,
    String? title,
    String? message,
  }) async {
    await _call('fail', {
      'id': id,
      if (title != null) 'title': title,
      if (message != null) 'message': message,
    });
  }

  Future<void> cancel({required String id}) async {
    await _call('cancel', {'id': id});
  }

  Future<void> _call(String method, Map<String, dynamic> args) async {
    try {
      await _channel.invokeMethod(method, args);
    } catch (_) {}
  }
}
