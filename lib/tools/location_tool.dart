import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'base_tool.dart';
import 'location_tool.g.dart';

/// 获取设备当前 GPS 定位。
///
/// 返回经度、纬度、精度、城市/区域等信息，用于天气查询、附近搜索等场景。
class LocationTool extends AgentTool {
  @override
  String get name => 'location';

  @override
  String get description => locationToolDescription;

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {},
    'required': [],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    // 1. 请求权限
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
    }
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        return '定位失败：位置权限已被永久拒绝，请在系统设置中手动开启。';
      }
      return '定位失败：位置权限未开启，请允许 DWeis 访问位置信息。';
    }

    // 2. 检查定位服务
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return '定位失败：设备定位服务未开启，请在系统设置中打开 GPS。';
    }

    // 3. 先拿缓存位置
    Position? position = await Geolocator.getLastKnownPosition();

    // 4. 尝试获取实时位置
    if (position == null) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        // 实时定位失败
      }
    }

    if (position == null) {
      return '定位失败：无法获取位置。请移动到开阔区域或确保 GPS 已开启后重试。';
    }

    final buf = StringBuffer();
    buf.writeln('经度: ${position.longitude}');
    buf.writeln('纬度: ${position.latitude}');
    buf.writeln('精度: ${position.accuracy.round()}m');

    if (position.altitude != null) {
      buf.writeln('海拔: ${position.altitude!.round()}m');
    }

    return buf.toString();
  }
}
