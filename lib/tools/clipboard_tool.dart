import 'package:flutter/services.dart';
import '../tools/base_tool.dart';
import 'clipboard_tool.g.dart';

class ClipboardTool extends AgentTool {
  @override String get name => 'clipboard';
  @override bool get readOnly => false;

  @override
  String get description => clipboardToolDescription;

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['read', 'write'],
        'description': '操作类型：read(读取剪贴板内容), write(写入文本到剪贴板)',
      },
      'text': {
        'type': 'string',
        'description': '要写入剪贴板的文本内容（write操作需要）',
      },
    },
    'required': ['action'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String?;

    if (action == null) {
      return '错误: 请提供操作类型(action)';
    }

    try {
      switch (action) {
        case 'read':
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          final text = data?.text;
          if (text == null || text.isEmpty) {
            return '剪贴板为空';
          }
          return '剪贴板内容:\n$text';

        case 'write':
          final text = args['text'] as String?;
          if (text == null || text.isEmpty) {
            return '错误: write 操作需要提供 text 参数';
          }
          await Clipboard.setData(ClipboardData(text: text));
          return '已复制到剪贴板 (${text.length} 字符)';

        default:
          return '错误: 不支持的操作 "$action"';
      }
    } catch (e) {
      return '剪贴板操作错误: $e';
    }
  }
}
