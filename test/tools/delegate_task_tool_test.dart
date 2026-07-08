import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/tools/tools.dart';

void main() {
  group('DelegateTaskTool', () {
    test('工具名、只读性与参数 schema', () {
      final tool = DelegateTaskTool(onDelegate: (_, __) async => '');
      expect(tool.name, 'delegate_task');
      expect(tool.readOnly, isTrue);
      expect(tool.parameters['type'], 'object');
      expect(
        tool.parameters['required'],
        containsAll(['agent', 'brief']),
      );
    });

    test('execute 把解析后的参数透传给 onDelegate 并返回其结果', () async {
      String? capturedAgent;
      String? capturedBrief;
      final tool = DelegateTaskTool(
        onDelegate: (a, b) async {
          capturedAgent = a;
          capturedBrief = b;
          return '子Agent说：done';
        },
      );
      final result = await tool.execute({
        'agent': '子Bot',
        'brief': '写一首关于春天的诗',
      });
      expect(capturedAgent, '子Bot');
      expect(capturedBrief, '写一首关于春天的诗');
      expect(result, '子Agent说：done');
    });

    test('参数缺失时返回可读的错误而非抛异常', () async {
      final tool = DelegateTaskTool(onDelegate: (_, __) async => 'x');
      final r1 = await tool.execute({'brief': '写诗'}); // 缺 agent
      final r2 = await tool.execute({'agent': '子Bot'}); // 缺 brief
      expect(r1, contains('agent'));
      expect(r2, contains('brief'));
    });
  });
}
