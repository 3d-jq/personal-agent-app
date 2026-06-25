import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/tools/tool_registry.dart';
import 'package:personal_agent_app/tools/clipboard_tool.dart';

void main() {
  group('ToolRegistry frequency limit', () {
    late ToolRegistry registry;

    setUp(() {
      registry = ToolRegistry();
      registry.register(ClipboardTool());
    });

    test('checkFrequencyLimit returns null below threshold', () {
      for (var i = 0; i < 10; i++) {
        expect(registry.checkFrequencyLimit('clipboard'), isNull);
      }
    });

    test('checkFrequencyLimit blocks at 11th call', () {
      for (var i = 0; i < 10; i++) {
        registry.checkFrequencyLimit('clipboard');
      }
      final msg = registry.checkFrequencyLimit('clipboard');
      expect(msg, isNotNull);
      expect(msg, contains('11'));
    });

    test('checkFrequencyWarning null at 7 calls', () {
      for (var i = 0; i < 7; i++) {
        registry.checkFrequencyLimit('clipboard');
      }
      expect(registry.checkFrequencyWarning('clipboard'), isNull);
    });

    test('checkFrequencyWarning warns at 8th call', () {
      for (var i = 0; i < 8; i++) {
        registry.checkFrequencyLimit('clipboard');
      }
      final warn = registry.checkFrequencyWarning('clipboard');
      expect(warn, isNotNull);
      expect(warn, contains('8'));
      expect(warn, contains('10'));
    });

    test('checkFrequencyWarning warns at 9th and 10th call', () {
      for (var i = 0; i < 9; i++) {
        registry.checkFrequencyLimit('clipboard');
      }
      expect(registry.checkFrequencyWarning('clipboard'), isNotNull);
      registry.checkFrequencyLimit('clipboard');
      expect(registry.checkFrequencyWarning('clipboard'), isNotNull);
    });

    test('resetCallCounts clears all', () {
      for (var i = 0; i < 5; i++) {
        registry.checkFrequencyLimit('clipboard');
      }
      registry.resetCallCounts();
      expect(registry.checkFrequencyLimit('clipboard'), isNull);
      expect(registry.checkFrequencyWarning('clipboard'), isNull);
    });

    test('counters per-tool', () {
      for (var i = 0; i < 10; i++) {
        registry.checkFrequencyLimit('clipboard');
      }
      expect(registry.checkFrequencyLimit('nonexistent'), isNull);
    });
  });
}
