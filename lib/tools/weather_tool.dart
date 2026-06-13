import 'dart:convert';
import 'package:dio/dio.dart';
import '../tools/base_tool.dart';

class WeatherTool extends AgentTool {
  @override
  String get name => 'weather';

  @override
  String get description => '查询实时天气信息。当用户询问天气时使用。需要提供 API Key（OpenWeatherMap），用户可在设置中配置。';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'city': {
        'type': 'string',
        'description': '城市名称，例如: "Beijing", "Shanghai", "London"',
      },
      'units': {
        'type': 'string',
        'description': '温度单位: metric(摄氏度), imperial(华氏度), standard(开尔文)。默认 metric',
      },
    },
    'required': ['city'],
  };

  String? apiKey;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    if (apiKey == null || apiKey!.isEmpty) {
      return '天气功能需要配置 API Key。请提供 OpenWeatherMap 的 API Key（免费申请: https://openweathermap.org/api）';
    }
    final city = args['city'] as String?;
    if (city == null || city.isEmpty) return '错误: 请提供城市名称';
    final units = args['units'] as String? ?? 'metric';

    try {
      final response = await _dio.get(
        'https://api.openweathermap.org/data/2.5/weather',
        queryParameters: {'q': city, 'appid': apiKey, 'units': units, 'lang': 'zh_cn'},
      );
      final data = response.data;
      final weather = data['weather'][0];
      final main = data['main'];
      final wind = data['wind'];
      final tempUnit = units == 'metric' ? '°C' : units == 'imperial' ? '°F' : 'K';
      return '''${data['name']} - ${data['sys']?['country']}
天气: ${weather['description']}
温度: ${main['temp']}$tempUnit (体感 ${main['feels_like']}$tempUnit)
范围: ${main['temp_min']}$tempUnit ~ ${main['temp_max']}$tempUnit
湿度: ${main['humidity']}%
风速: ${wind['speed']} m/s''';
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) return 'API Key 无效，请检查配置';
      if (code == 404) return '找不到城市 "$city"，请检查拼写';
      return '天气服务暂时不可用 ($code)';
    } catch (e) {
      return '天气查询错误: $e';
    }
  }
}
