import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/tools/tools.dart';

void main() {
  group('ToolRegistry', () {
    test('register and retrieve tools', () {
      final registry = ToolRegistry();
      registry.register(WeatherTool(apiKey: ''));
      registry.register(ReminderTool());

      expect(registry.all.length, 2);
      expect(registry.all.any((t) => t.name == 'weather'), true);
      expect(registry.all.any((t) => t.name == 'reminder'), true);
    });

    test('functionDefinitions format', () {
      final registry = ToolRegistry();
      registry.register(WeatherTool(apiKey: ''));

      final defs = registry.functionDefinitions;
      expect(defs.length, 1);
      expect(defs[0]['type'], 'function');
      expect((defs[0]['function'] as Map)['name'], 'weather');
    });

    test('duplicate registration replaces', () {
      final registry = ToolRegistry();
      registry.register(WeatherTool(apiKey: ''));
      registry.register(WeatherTool(apiKey: ''));

      expect(registry.all.length, 1);
    });
  });

  group('context_doc split tools', () {
    test('ContextDocReadTool 要求 doc 参数', () {
      final tool = ContextDocReadTool();
      final required = tool.parameters['required'] as List;
      expect(required, contains('doc'));
      expect(tool.name, 'context_doc_read');
    });

    test('ContextDocUpdateTool 要求 doc 和 content 参数', () {
      final tool = ContextDocUpdateTool();
      final required = tool.parameters['required'] as List;
      expect(required, contains('doc'));
      expect(required, contains('content'));
      expect(tool.name, 'context_doc_update');
    });
  });
}
