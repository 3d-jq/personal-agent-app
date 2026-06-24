import 'base_tool.dart';
import 'ask_user_tool.g.dart';

/// 阻塞型工具：当大模型遇到不确定或需要用户确认的事项时，暂停响应流程并询问用户。
///
/// 工具执行后会阻塞，直到用户回复；用户回复内容会作为工具结果返回给模型，
/// 模型可基于该回复继续后续推理或调用其他工具。
class AskUserTool extends AgentTool {
  /// 向用户提问并等待回复的回调。由上层控制器注入，确保工具不直接依赖 UI。
  final Future<String> Function(String prompt)? onAsk;

  AskUserTool({this.onAsk});

  @override
  String get name => 'ask_user';

  @override
  String get description => askUserToolDescription;

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'prompt': {'type': 'string', 'description': '需要询问用户的具体问题'},
    },
    'required': ['prompt'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final prompt = args['prompt']?.toString() ?? '';
    if (prompt.isEmpty) {
      return '询问失败：prompt 不能为空';
    }
    if (onAsk == null) {
      return '询问失败：用户交互通道未配置';
    }
    return await onAsk!(prompt);
  }
}
