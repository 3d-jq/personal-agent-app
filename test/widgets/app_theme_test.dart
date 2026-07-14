import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/app.dart';
import 'package:personal_agent_app/core/design_tokens.dart';

/// 验证 App 主题层统一圆角范式：
/// 所有 PopupMenuButton / 卡片 / 按钮均走 RadiusToken.md（12），
/// 而非散落的 magic number，保证全 App 视觉节奏一致。
void main() {
  group('App 主题统一圆角范式', () {
    test('popupMenuTheme 使用统一圆角 RadiusToken.md', () {
      final theme = buildAppTheme(Brightness.light);
      final shape = theme.popupMenuTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      if (shape is RoundedRectangleBorder) {
        expect(shape.borderRadius, equals(BorderRadius.circular(RadiusToken.md)));
      }
    });

    test('cardTheme 圆角为 RadiusToken.md', () {
      final theme = buildAppTheme(Brightness.light);
      final shape = theme.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      if (shape is RoundedRectangleBorder) {
        expect(shape.borderRadius, equals(BorderRadius.circular(RadiusToken.md)));
      }
    });

    test('elevatedButton 圆角为 RadiusToken.md', () {
      final theme = buildAppTheme(Brightness.light);
      final shape =
          theme.elevatedButtonTheme.style?.shape?.resolve(const <WidgetState>{});
      expect(shape, isA<RoundedRectangleBorder>());
      if (shape is RoundedRectangleBorder) {
        expect(shape.borderRadius, equals(BorderRadius.circular(RadiusToken.md)));
      }
    });

    test('outlinedButton 圆角为 RadiusToken.md', () {
      final theme = buildAppTheme(Brightness.light);
      final shape =
          theme.outlinedButtonTheme.style?.shape?.resolve(const <WidgetState>{});
      expect(shape, isA<RoundedRectangleBorder>());
      if (shape is RoundedRectangleBorder) {
        expect(shape.borderRadius, equals(BorderRadius.circular(RadiusToken.md)));
      }
    });
  });
}
