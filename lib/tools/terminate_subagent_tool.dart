import 'base_tool.dart';

/// 群聊协调者用于「终止」一个正在运行（或已卡死/无响应）的子 Agent 的虚拟工具。
///
/// 与 [DelegateTaskTool] 对称：子 Agent 被视为主 Agent 可调度的「任务」，
/// 主 Agent 不仅能派活，也能在子 Agent 出错、长时间无响应或无需继续时主动结束它。
/// 回调 [onTerminate] 由 [GroupChatController] 注入：完成该子 Agent 执行流的
/// abort 信号，使其流式任务立即以「[已被终止]」收尾，并把该结果作为 delegate_task
/// 的工具结果回灌协调者，由协调者决定继续、重试或汇总。
class TerminateSubagentTool extends AgentTool {
  /// 终止回调：传入子 Agent 的群内名字，返回终止结果文本。
  final Future<String> Function(String agentName) onTerminate;

  TerminateSubagentTool({required this.onTerminate});

  @override
  String get name => 'terminate_subagent';

  @override
  String get description =>
      '立即终止一个正在运行（或已卡死、长时间无响应）的子 Agent。'
      '当你发现某个子 Agent 执行出错、迟迟没有反应、或它的回答已不需要时，'
      '调用本工具并传入其群内名字即可强制结束它；结束后你可基于已有结果继续、'
      '改派其他子 Agent，或直接汇总。仅在子 Agent 行为异常时使用，正常完成的子 Agent 无需终止。'
      '注意：本工具只终止「当前正在运行」的子 Agent；若它已完成或尚未开始，会告知你无法终止。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'agent': {
            'type': 'string',
            'description': '要终止的子 Agent 的群内名字（精确匹配，如「美食推荐官」）。',
          },
        },
        'required': ['agent'],
      };

  @override
  bool get readOnly => true;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final agentName = (args['agent'] as String?)?.trim() ?? '';
    if (agentName.isEmpty) {
      return '终止失败：缺少 agent 参数（子 Agent 名字）。';
    }
    try {
      return await onTerminate(agentName);
    } catch (e) {
      return '终止执行出错：$e';
    }
  }
}
