import '../tools/base_tool.dart';

class TimeTool extends AgentTool {
  @override
  String get name => 'get_current_time';

  @override
  String get description => '获取当前日期、时间和星期。';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {},
  };

  static const _weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日', ];

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final now = DateTime.now();
    final wd = _weekdays[now.weekday - 1];
    return '${now.year}年${now.month}月${now.day}日 $wd ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }
}
