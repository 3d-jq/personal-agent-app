import 'dart:async';

/// Simple async mutex for serializing file writes.
class AsyncLock {
  Future<void>? _last;

  Future<T> run<T>(Future<T> Function() fn) async {
    final prev = _last;
    final completer = Completer<void>();
    _last = completer.future;
    try {
      await prev;
      return await fn();
    } finally {
      completer.complete();
    }
  }
}
