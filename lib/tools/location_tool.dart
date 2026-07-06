import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/service_locator.dart';
import '../tools/base_tool.dart';
import '../tools/weather_tool.dart';
import 'location_tool.g.dart';

/// 获取设备当前 GPS 定位，并反向地理编码获取具体地址。
///
/// 返回经度、纬度、精度、具体地址等信息。
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

    // 3. 获取实时高精度位置
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 30),
        ),
      );
    } catch (_) {
      // 实时定位失败，尝试获取缓存位置
    }

    // 4. 如果实时定位失败，尝试获取缓存位置
    if (position == null) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    if (position == null) {
      return '定位失败：无法获取位置。请移动到开阔区域或确保 GPS 已开启后重试。';
    }

    // 5. 反向地理编码：获取具体地址
    String address = '';
    try {
      address = await _reverseGeocode(position.latitude, position.longitude);
    } catch (_) {}

    final buf = StringBuffer();
    if (address.isNotEmpty) {
      buf.writeln('地址: $address');
    }
    buf.writeln('经度: ${position.longitude}');
    buf.writeln('纬度: ${position.latitude}');
    buf.writeln('精度: ${position.accuracy.round()}m');

    if (position.altitude != null) {
      buf.writeln('海拔: ${position.altitude!.round()}m');
    }

    return buf.toString();
  }

  /// 反向地理编码：使用高德地图 API 将经纬度转换为地址
  Future<String> _reverseGeocode(double latitude, double longitude) async {
    // 获取高德地图 API Key
    final weatherTool = getIt<WeatherTool>();
    final apiKey = weatherTool.apiKey;
    if (apiKey == null || apiKey.isEmpty) return '';

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://restapi.amap.com/v3/geocode/regeo',
        queryParameters: {
          'key': apiKey,
          'location': '$longitude,$latitude',
          'extensions': 'base',
        },
      );

      if (response.data['status'] == '1') {
        final regeocode = response.data['regeocode'];
        if (regeocode != null) {
          final addressComponent = regeocode['addressComponent'];
          if (addressComponent != null) {
            final province = addressComponent['province'] ?? '';
            final city = addressComponent['city'] ?? '';
            final district = addressComponent['district'] ?? '';
            final township = addressComponent['township'] ?? '';
            
            final parts = [province, city, district, township]
                .where((p) => p.isNotEmpty && p != city)
                .toList();
            return parts.join('');
          }
        }
      }
    } catch (_) {}

    return '';
  }
}
