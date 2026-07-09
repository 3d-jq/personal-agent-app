import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/tools/tools.dart';

void main() {
  group('ToolRegistry frequency limit', () {
    late ToolRegistry registry;

    setUp(() {
      registry = ToolRegistry();
      registry.register(WeatherTool(apiKey: ''));
    });

    test('checkFrequencyLimit returns null below threshold', () {
      for (var i = 0; i < 10; i++) {
        expect(registry.checkFrequencyLimit('weather'), isNull);
      }
    });

    test('checkFrequencyLimit blocks at 11th call', () {
      for (var i = 0; i < 10; i++) {
        registry.checkFrequencyLimit('weather');
      }
      final msg = registry.checkFrequencyLimit('weather');
      expect(msg, isNotNull);
      expect(msg, contains('11'));
    });

    test('checkFrequencyWarning null at 7 calls', () {
      for (var i = 0; i < 7; i++) {
        registry.checkFrequencyLimit('weather');
      }
      expect(registry.checkFrequencyWarning('weather'), isNull);
    });

    test('checkFrequencyWarning warns at 8th call', () {
      for (var i = 0; i < 8; i++) {
        registry.checkFrequencyLimit('weather');
      }
      final warn = registry.checkFrequencyWarning('weather');
      expect(warn, isNotNull);
      expect(warn, contains('8'));
      expect(warn, contains('10'));
    });

    test('checkFrequencyWarning warns at 9th and 10th call', () {
      for (var i = 0; i < 9; i++) {
        registry.checkFrequencyLimit('weather');
      }
      expect(registry.checkFrequencyWarning('weather'), isNotNull);
      registry.checkFrequencyLimit('weather');
      expect(registry.checkFrequencyWarning('weather'), isNotNull);
    });

    test('resetCallCounts clears all', () {
      for (var i = 0; i < 5; i++) {
        registry.checkFrequencyLimit('weather');
      }
      registry.resetCallCounts();
      expect(registry.checkFrequencyLimit('weather'), isNull);
      expect(registry.checkFrequencyWarning('weather'), isNull);
    });

    test('counters per-tool', () {
      for (var i = 0; i < 10; i++) {
        registry.checkFrequencyLimit('weather');
      }
      expect(registry.checkFrequencyLimit('nonexistent'), isNull);
    });
  });
}
