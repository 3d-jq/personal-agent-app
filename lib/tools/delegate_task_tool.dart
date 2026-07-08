import 'base_tool.dart';

/// 群聊协调者用于「派活」给子 Agent 的虚拟工具。
///
/// 它不是真正执行外部动作，而是把派活意图交给控制器确定性执行：
/// 控制器收到回调后，把对应子 Agent 在隔离上下文（用户原始需求 + 任务简报）中
/// 跑一次，并把子 Agent 的最终文本作为工具结果回灌给协调者，由协调者决定
/// 继续派活还是汇总。
///
/// 对齐 OpenCode 的 `task` 工具派活模式——「问用户」用自然语言文本输出，
/// 「派活」用工具调用，二者结构性分离，彻底摆脱靠解析 `@名字` 文本派活的脆弱机制。
class DelegateTaskTool extends AgentTool {
  /// 派活回调：由 [GroupChatController] 注入。
  /// [agentName] 为子 Agent 的群内名字；[brief] 为自包含任务简报。
  /// 返回子 Agent 执行后的最终文本（作为工具结果回灌协调者）。
  final Future<String> Function(String agentName, String brief) onDelegate;

  DelegateTaskTool({required this.onDelegate});

  @override
  String get name => 'delegate_task';

  @override
  String get description =>
      '把一项子任务分派给指定子 Agent 执行。'
      '当需要某位子 Agent 的专业能力时，调用本工具并附上自包含的任务简报。'
      '子 Agent 会在隔离上下文中只看到用户原始需求与本简报，因此简报必须写清：'
      '要它做什么、期望产出什么、有何约束。'
      '注意：不要在自然语言里用 @名字 来派活——@ 只是普通提及，不会触发任何执行；'
      '真正的派活只能通过本工具。'
      '如需多位子 Agent 协作，依次多次调用本工具即可。'
      '所有需要的子 Agent 都回答完毕后，停止调用本工具，用一两句话做简短收尾'
      '（告诉用户任务已完成、点一下要点），不要复述子 Agent 已经给出的内容。';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'agent': {
        'type': 'string',
        'description': '要派活的子 Agent 的群内名字（精确匹配，如「美食推荐官」）。',
      },
      'brief': {
        'type': 'string',
        'description': '自包含的任务简报：写清要子 Agent 做什么、期望产出、约束条件。'
            '子 Agent 看不到完整群历史，简报必须让它无需追问即可开工。',
      },
    },
    'required': ['agent', 'brief'],
  };

  @override
  bool get readOnly => true;

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final agentName = (args['agent'] as String?)?.trim() ?? '';
    final brief = (args['brief'] as String?)?.trim() ?? '';
    if (agentName.isEmpty) {
      return '派活失败：缺少 agent 参数（子 Agent 名字）。';
    }
    if (brief.isEmpty) {
      return '派活失败：缺少 brief 参数（任务简报）。';
    }
    try {
      return await onDelegate(agentName, brief);
    } catch (e) {
      return '派活执行出错：$e';
    }
  }
}
