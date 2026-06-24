import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// connectivity_plus 6.x 起，checkConnectivity() 和 onConnectivityChanged
  /// 都返回 List<ConnectivityResult>。只要存在任一非 none 的连接即视为在线。
  static bool _isConnected(List<ConnectivityResult> result) =>
      result.any((r) => r != ConnectivityResult.none);

  Future<void> init() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(result);
    _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = _isConnected(result);
      _controller.add(_isOnline);
    });
  }

  Future<bool> check() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(result);
    return _isOnline;
  }

  void dispose() => _controller.close();
}
