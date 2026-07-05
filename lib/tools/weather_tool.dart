import 'package:dio/dio.dart';
import '../tools/base_tool.dart';
import 'weather_tool.g.dart';

class WeatherTool extends AgentTool {
  @override
  String get name => 'weather';

  @override
  String get description => weatherToolDescription;

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'city': {'type': 'string', 'description': '城市名称，例如: "北京", "上海", "广州"'},
      'days': {
        'type': 'integer',
        'description': '查询未来第几天。0 表示今天（当前天气），1 表示明天，最大 3。默认 0',
        'minimum': 0,
        'maximum': 3,
      },
      'units': {
        'type': 'string',
        'description': '温度单位: metric(摄氏度), imperial(华氏度)。默认 metric',
      },
    },
    'required': ['city'],
  };

  final String? apiKey;

  WeatherTool({this.apiKey});

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    if (apiKey == null || apiKey!.isEmpty) {
      return '天气功能需要配置高德地图 Web 服务 API Key';
    }
    final city = args['city'] as String?;
    if (city == null || city.isEmpty) return '错误: 请提供城市名称';
    final units = args['units'] as String? ?? 'metric';
    final days = (args['days'] as int?)?.clamp(0, 3) ?? 0;

    try {
      final response = await _dio.get(
        'https://restapi.amap.com/v3/weather/weatherInfo',
        queryParameters: {
          'key': apiKey,
          'city': city,
          'extensions': days == 0 ? 'base' : 'all',
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null) return '天气服务返回数据异常';

      final status = data['status']?.toString();
      if (status != '1') {
        final info = data['info']?.toString();
        return '天气查询失败：${_gaodeError(info)}';
      }

      if (days == 0) {
        return _formatCurrent(data, city, units);
      } else {
        return _formatForecast(data, city, units, days);
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final reason = code == null
          ? '网络连接失败'
          : code >= 500
          ? '高德服务异常'
          : '请求异常';
      return '天气服务不可用：$reason (${code ?? '无响应'})';
    } catch (e) {
      return '天气查询错误: $e';
    }
  }

  String _tempUnit(String units) => units == 'imperial' ? '°F' : '°C';

  double _toFahrenheit(double c) => c * 9 / 5 + 32;

  String _formatTemp(String? celsius, String units) {
    if (celsius == null) return '-';
    final c = double.tryParse(celsius);
    if (c == null) return celsius;
    if (units == 'imperial') {
      return '${_toFahrenheit(c).toStringAsFixed(1)}°F';
    }
    return '${celsius}°C';
  }

  String _formatCurrent(Map<String, dynamic> data, String city, String units) {
    final lives = (data['lives'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>();
    if (lives == null || lives.isEmpty) {
      return '未找到 $city 的实时天气数据';
    }
    final live = lives.first;
    return '''$city - 当前天气
天气: ${live['weather']}
温度: ${_formatTemp(live['temperature']?.toString(), units)}
湿度: ${live['humidity']}%
风向: ${live['winddirection']}
风力: ${live['windpower']}级
发布时间: ${live['reporttime']}''';
  }

  String _formatForecast(
    Map<String, dynamic> data,
    String city,
    String units,
    int days,
  ) {
    final forecasts = (data['forecasts'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>();
    if (forecasts == null || forecasts.isEmpty) {
      return '未找到 $city 的预报数据';
    }
    final casts = (forecasts.first['casts'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>();
    if (casts == null || casts.isEmpty) {
      return '未找到 $city 的预报数据';
    }
    if (days >= casts.length) {
      return '仅支持未来 ${casts.length - 1} 天的预报';
    }
    final day = casts[days];
    final label = days == 1
        ? '明天'
        : days == 2
        ? '后天'
        : '未来第 $days 天';
    return '''$city - ${day['date']} $label
天气: 白天${day['dayweather']} / 夜间${day['nightweather']}
温度: ${_formatTemp(day['nighttemp']?.toString(), units)} ~ ${_formatTemp(day['daytemp']?.toString(), units)}
风向: 白天${day['daywind']} / 夜间${day['nightwind']}
风力: 白天${day['daypower']}级 / 夜间${day['nightpower']}级''';
  }

  String _gaodeError(String? info) {
    final map = {
      'INVALID_USER_KEY': 'API Key 无效',
      'USERKEY_PLAT_NOMATCH': 'API Key 与平台不匹配',
      'INSUFFICIENT_PRIVILEGES': 'API Key 无天气接口权限',
      'INVALID_PARAMS': '请求参数错误',
      'DAILY_QUERY_OVER_LIMIT': '超过每日调用限额',
      'QPS_HAS_EXCEEDED_THE_LIMIT': '请求过于频繁',
    };
    return map[info] ?? '服务异常 (${info ?? '未知错误'})';
  }
}
