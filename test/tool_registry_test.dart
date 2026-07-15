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
      for (var i = 0; i < 15; i++) {
        expect(registry.checkFrequencyLimit('weather'), isNull);
      }
    });

    test('checkFrequencyLimit blocks at 16th call', () {
      for (var i = 0; i < 15; i++) {
        registry.checkFrequencyLimit('weather');
      }
      final msg = registry.checkFrequencyLimit('weather');
      expect(msg, isNotNull);
      expect(msg, contains('16'));
    });

    test('checkFrequencyWarning null at 12 calls', () {
      for (var i = 0; i < 12; i++) {
        registry.checkFrequencyLimit('weather');
      }
      expect(registry.checkFrequencyWarning('weather'), isNull);
    });

    test('checkFrequencyWarning warns at 13th call', () {
      for (var i = 0; i < 13; i++) {
        registry.checkFrequencyLimit('weather');
      }
      final warn = registry.checkFrequencyWarning('weather');
      expect(warn, isNotNull);
      expect(warn, contains('13'));
      expect(warn, contains('15'));
    });

    test('checkFrequencyWarning warns at 14th and 15th call', () {
      for (var i = 0; i < 14; i++) {
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
