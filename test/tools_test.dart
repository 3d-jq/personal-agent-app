import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/tools/clipboard_tool.dart';
import 'package:personal_agent_app/tools/context_doc_tool.dart';
import 'package:personal_agent_app/tools/tools.dart';
import 'package:personal_agent_app/tools/weather_tool.dart';

void main() {
  group('ToolRegistry', () {
    test('register and retrieve tools', () {
      final registry = ToolRegistry();
      registry.register(ClipboardTool());
      registry.register(WeatherTool());

      expect(registry.all.length, 2);
      expect(registry.all.any((t) => t.name == 'clipboard'), true);
      expect(registry.all.any((t) => t.name == 'weather'), true);
    });

    test('functionDefinitions format', () {
      final registry = ToolRegistry();
      registry.register(ClipboardTool());

      final defs = registry.functionDefinitions;
      expect(defs.length, 1);
      expect(defs[0]['type'], 'function');
      expect((defs[0]['function'] as Map)['name'], 'clipboard');
    });

    test('duplicate registration replaces', () {
      final registry = ToolRegistry();
      registry.register(ClipboardTool());
      registry.register(ClipboardTool());

      expect(registry.all.length, 1);
    });
  });

  group('ContextDocTool', () {
    test('declares read and update actions', () {
      final tool = ContextDocTool();
      final action = tool.parameters['properties']['action'] as Map;
      final actions = (action['enum'] as List).cast<String>();

      expect(actions, contains('read'));
      expect(actions, contains('update'));
    });
  });

  group('ClipboardTool', () {
    test('returns error when action is missing', () async {
      final tool = ClipboardTool();
      final result = await tool.execute({});
      expect(result, contains('错误'));
    });
  });
}
