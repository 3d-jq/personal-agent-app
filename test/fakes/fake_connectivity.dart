import 'package:personal_agent_app/services/connectivity_service.dart';

class FakeConnectivity extends ConnectivityService {
  final bool isConnected;

  FakeConnectivity({this.isConnected = true});

  @override
  Future<bool> check() async => isConnected;
}
