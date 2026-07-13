import 'dart:async';

import 'package:personal_agent_app/services/log_service.dart';

/// Simple async mutex for serializing file writes.
class AsyncLock {
  Future<void>? _last;

  Future<T> run<T>(Future<T> Function() fn) async {
    final prev = _last;
    final completer = Completer<void>();
    _last = completer.future;
    try {
      try {
        await prev;
      } catch (e) {
        // 前一个任务失败不阻塞后续任务，但记录异常便于排查
        log.w('AsyncLock', 'Previous task failed, proceeding', e);
      }
      return await fn();
    } finally {
      completer.complete();
    }
  }
}
