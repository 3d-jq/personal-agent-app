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
    // 检查权限
    var status = await Permission.location.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      status = await Permission.location.request();
    }
    if (!status.isGranted) {
      return '定位失败：位置权限未开启，请在系统设置中允许 DWeis 访问位置信息。';
    }

    // 检查定位服务是否开启
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return '定位失败：设备定位服务未开启，请在系统设置中打开 GPS。';
    }

    try {
      // ① 先拿缓存位置（瞬间返回）
      Position? position = await Geolocator.getLastKnownPosition();

      // ② 尝试获取实时位置（30s 超时，低精度更快）
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 30),
          ),
        );
      } catch (_) {
        // 实时定位超时，用缓存兜底
      }

      if (position == null) {
        return '定位失败：无法获取位置，请移动到开阔区域后重试。';
      }

      final buf = StringBuffer();
      buf.writeln('经度: ${position.longitude}');
      buf.writeln('纬度: ${position.latitude}');
      buf.writeln('精度: ${position.accuracy.round()}m');

      if (position.altitude != null) {
        buf.writeln('海拔: ${position.altitude!.round()}m');
      }

      return buf.toString();
    } catch (e) {
      return '定位失败: $e';
    }
  }
}
