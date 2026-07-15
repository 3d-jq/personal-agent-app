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

    test('dialogTheme 无阴影白卡统一圆角 RadiusToken.md', () {
      final theme = buildAppTheme(Brightness.light);
      final d = theme.dialogTheme;
      expect(d.elevation, equals(0));
      expect(d.shadowColor, equals(Colors.transparent));
      expect(d.shape, isA<RoundedRectangleBorder>());
      if (d.shape is RoundedRectangleBorder) {
        expect(
          (d.shape! as RoundedRectangleBorder).borderRadius,
          equals(BorderRadius.circular(RadiusToken.md)),
        );
      }
    });

    test('bottomSheetTheme 无阴影顶部大圆角 RadiusToken.lg', () {
      final theme = buildAppTheme(Brightness.light);
      final b = theme.bottomSheetTheme;
      expect(b.elevation, equals(0));
      expect(b.shadowColor, equals(Colors.transparent));
      expect(b.shape, isA<RoundedRectangleBorder>());
      if (b.shape is RoundedRectangleBorder) {
        expect(
          (b.shape! as RoundedRectangleBorder).borderRadius,
          equals(BorderRadius.vertical(top: Radius.circular(RadiusToken.lg))),
        );
      }
    });
  });
}
