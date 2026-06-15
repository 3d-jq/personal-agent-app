import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/tools/tools.dart';

void main() {
  group('ToolRegistry', () {
    test('register and retrieve tools', () {
      final registry = ToolRegistry();
      registry.register(TimeTool());
      registry.register(ClipboardTool());

      expect(registry.all.length, 2);
      expect(registry.all.any((t) => t.name == 'get_current_time'), true);
      expect(registry.all.any((t) => t.name == 'clipboard'), true);
    });

    test('functionDefinitions format', () {
      final registry = ToolRegistry();
      registry.register(TimeTool());

      final defs = registry.functionDefinitions;
      expect(defs.length, 1);
      expect(defs[0]['type'], 'function');
      expect((defs[0]['function'] as Map)['name'], 'get_current_time');
    });

    test('duplicate registration replaces', () {
      final registry = ToolRegistry();
      registry.register(TimeTool());
      registry.register(TimeTool());

      expect(registry.all.length, 1);
    });
  });

  group('TimeTool', () {
    test('returns current time', () async {
      final tool = TimeTool();
      final result = await tool.execute({});
      expect(result, isNotEmpty);
      expect(result, contains(':'));
    });
  });
}
