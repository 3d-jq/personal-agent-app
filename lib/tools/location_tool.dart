import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../tools/base_tool.dart';
import '../services/log_service.dart';
import 'location_tool.g.dart';

/// 获取设备当前 GPS 定位，并反向地理编码获取精确地址和附近 POI。
///
/// 返回经纬度、精度、完整地址（含街道门牌号）、附近兴趣点等信息。
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

    // 3. 优先用缓存位置（10 分钟内有效）
    Position? position;
    try {
      position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        final age = DateTime.now().difference(position.timestamp).inMinutes;
        if (age < 10) {
          // 缓存位置足够新鲜，直接使用，不触发实时请求
          return _formatResult(position);
        }
      }
    } catch (_) {}

    // 4. 缓存过期 → 获取实时位置（10 秒超时）
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      log.w('LocationTool', '实时定位失败: $e');
    }

    // 5. 实时失败 → 回退到缓存（即使过期也用，好过无数据）
    if (position == null) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (e) {
        log.w('LocationTool', '获取缓存位置失败: $e');
      }
    }

    if (position == null) {
      return '定位失败：无法获取位置。请移动到开阔区域或确保 GPS 已开启后重试。';
    }

    return _formatResult(position);
  }

  /// 格式化位置输出（含反向地理编码）
  Future<String> _formatResult(Position position) async {
    final geocodeResult = await _reverseGeocode(
      position.latitude,
      position.longitude,
    );

    final buf = StringBuffer();
    if (geocodeResult.address.isNotEmpty) {
      buf.writeln('地址: ${geocodeResult.address}');
    }
    buf.writeln('经度: ${position.longitude}');
    buf.writeln('纬度: ${position.latitude}');
    buf.writeln('精度: ±${position.accuracy.round()}m');
    buf.writeln('海拔: ${position.altitude.round()}m');

    return buf.toString();
  }

  /// 反向地理编码：使用 Android 原生 Geocoder（零 API key 依赖）
  Future<_GeocodeResult> _reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    final result = _GeocodeResult();

    try {
      final placemarks =
          await Geocoding().placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        result.address = [
          if (p.street?.isNotEmpty == true) p.street,
          if (p.locality?.isNotEmpty == true) p.locality,
          if (p.subAdministrativeArea?.isNotEmpty == true)
            p.subAdministrativeArea,
          if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea,
          if (p.country?.isNotEmpty == true) p.country,
        ].join(', ');
      }
    } catch (e) {
      log.w('LocationTool', 'Geocoder 失败: $e');
    }

    return result;
  }
}

/// 地理编码结果
class _GeocodeResult {
  String address = '';
}
