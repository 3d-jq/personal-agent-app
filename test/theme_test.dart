import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';

void main() {
  group('AgentColors', () {
    test('light theme has correct properties', () {
      final colors = AgentColors.light();
      expect(colors.background, isNotNull);
      expect(colors.surface, isNotNull);
      expect(colors.textPrimary, isNotNull);
      expect(colors.textSecondary, isNotNull);
    });

    test('dark theme has correct properties', () {
      final colors = AgentColors.dark();
      expect(colors.background, isNotNull);
      expect(colors.surface, isNotNull);
      expect(colors.textPrimary, isNotNull);
      expect(colors.textSecondary, isNotNull);
    });

    test('light and dark themes have different backgrounds', () {
      final light = AgentColors.light();
      final dark = AgentColors.dark();
      expect(light.background, isNot(equals(dark.background)));
    });
  });
}
