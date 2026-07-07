import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

    // 3. 获取实时高精度位置
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 30),
        ),
      );
    } catch (e) {
      log.w('LocationTool', '实时定位失败: $e');
    }

    // 4. 如果实时定位失败，尝试获取缓存位置
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

    // 5. 反向地理编码：获取精确地址和附近 POI
    final geocodeResult = await _reverseGeocode(
      position.latitude,
      position.longitude,
    );

    final buf = StringBuffer();
    if (geocodeResult.address.isNotEmpty) {
      buf.writeln('地址: ${geocodeResult.address}');
    }
    if (geocodeResult.pois.isNotEmpty) {
      buf.writeln('附近地点:');
      for (final poi in geocodeResult.pois) {
        buf.writeln('  - ${poi.name}（${poi.distance}m, ${poi.type}）');
      }
    }
    buf.writeln('经度: ${position.longitude}');
    buf.writeln('纬度: ${position.latitude}');
    buf.writeln('精度: ±${position.accuracy.round()}m');
    buf.writeln('海拔: ${position.altitude.round()}m');

    return buf.toString();
  }

  /// 反向地理编码：使用高德地图 API 将经纬度转换为精确地址和 POI
  Future<_GeocodeResult> _reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    final result = _GeocodeResult();

    // 直接从环境变量获取高德地图 API Key
    final apiKey = dotenv.env['GAODE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return result;

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://restapi.amap.com/v3/geocode/regeo',
        queryParameters: {
          'key': apiKey,
          'location': '$longitude,$latitude',
          // extensions=all 返回完整地址 + 附近 POI
          'extensions': 'all',
          // 搜索半径 1000m 内的 POI
          'poitype': '',
          'radius': '1000',
          'roadlevel': '0',
          // 返回 POI 数量
          'num': '5',
        },
        options: Options(
          headers: {
            'Accept-Charset': 'utf-8',
          },
          responseType: ResponseType.plain,
        ),
      );

      final responseBody = response.data;
      Map<String, dynamic> data;
      if (responseBody is String) {
        data = jsonDecode(responseBody) as Map<String, dynamic>;
      } else {
        data = responseBody as Map<String, dynamic>;
      }

      if (data['status'] == '1') {
        final regeocode = data['regeocode'];
        if (regeocode != null) {
          // 完整格式化地址（含街道门牌号）
          final formatted = regeocode['formatted_address'];
          if (formatted != null && formatted is String && formatted.isNotEmpty) {
            result.address = formatted;
          }

          // 解析地址组件作为兜底
          if (result.address.isEmpty) {
            final addressComponent = regeocode['addressComponent'];
            if (addressComponent != null) {
              final province = (addressComponent['province'] ?? '').toString();
              final city = (addressComponent['city'] ?? '').toString();
              final district =
                  (addressComponent['district'] ?? '').toString();
              final township =
                  (addressComponent['township'] ?? '').toString();
              final street = (addressComponent['street'] ?? '').toString();
              final streetNumber =
                  (addressComponent['streetNumber'] ?? '').toString();

              final parts = [
                if (province.isNotEmpty) province,
                if (city.isNotEmpty && city != province) city,
                if (district.isNotEmpty) district,
                if (township.isNotEmpty) township,
                if (street.isNotEmpty) street,
                if (streetNumber.isNotEmpty) streetNumber,
              ];
              result.address = parts.join('');
            }
          }

          // 解析附近 POI 列表
          final pois = regeocode['pois'];
          if (pois is List) {
            for (final poi in pois.take(5)) {
              if (poi is Map) {
                final name = poi['name']?.toString() ?? '';
                final distance = poi['distance']?.toString() ?? '';
                final type = poi['type']?.toString() ?? '';
                if (name.isNotEmpty) {
                  result.pois.add(_Poi(
                    name: name,
                    distance: distance,
                    type: type,
                  ));
                }
              }
            }
          }
        }
      }
    } catch (e) {
      log.w('LocationTool', '反向地理编码失败: $e');
    }

    return result;
  }
}

/// 地理编码结果
class _GeocodeResult {
  String address = '';
  List<_Poi> pois = [];
}

/// 兴趣点
class _Poi {
  final String name;
  final String distance;
  final String type;
  _Poi({required this.name, required this.distance, required this.type});
}
