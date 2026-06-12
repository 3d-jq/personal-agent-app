import 'dart:convert';
import 'package:http/http.dart' as http;
import '../tools/base_tool.dart';

class AiDailyTool extends AgentTool {
  @override
  String get name => 'ai_daily';

  @override
  String get description => '获取今日AI信息。当用户询问今天的AI新闻、热点或趋势时使用。';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {},
    'required': [],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final url = Uri.parse('https://aihot.virxact.com/api/public/daily');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return '获取AI信息失败 (${response.statusCode})';
      }

      final data = jsonDecode(response.body);
      // 简单格式化返回，如果需要更复杂的处理可以调整
      return jsonEncode(data);
    } catch (e) {
      return '获取AI信息错误: $e';
    }
  }
}