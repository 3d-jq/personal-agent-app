import 'dart:convert';
import 'package:dio/dio.dart';
import '../tools/base_tool.dart';
import 'ai_daily_tool.g.dart';

class AiDailyTool extends AgentTool {
  @override
  String get name => 'ai_daily';

  @override
  String get description => aiDailyToolDescription;

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {},
    'required': [],
  };

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final response = await _dio.get(
        'https://aihot.virxact.com/api/public/daily',
      );
      if (response.statusCode != 200) {
        return '获取AI信息失败 (${response.statusCode})';
      }
      return jsonEncode(response.data);
    } on DioException {
      return '获取AI信息失败';
    } catch (e) {
      return '获取AI信息错误: $e';
    }
  }
}
