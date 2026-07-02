import 'package:flutter/material.dart';

/// Claude Design System v1.2 配色封装。
///
/// 仅保留一套风格：浅色 / 深色模式，均使用 Claude 的暖色调与强调色。
class AgentColors extends ThemeExtension<AgentColors> {
  // ── Text ──
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  // ── Backgrounds ──
  final Color _background;
  final Color surface;
  final Color primarySurface;
  final Color cardBackground;

  // ── Brand / Accent ──
  final Color primary;
  final Color primaryHover;

  // ── Functional ──
  final Color success;
  final Color warning;
  final Color error;

  // ── Dividers & borders ──
  final Color divider;

  Color get background => _background;
  Color get inputBg => surface;
  Color get chipBg => primarySurface;
  Color get chipBorder => divider;
  Color get navBg => surface;
  Color get cardBg => cardBackground;
  Color get iconBtnBg => primarySurface;

  const AgentColors._({
    required Color background,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.surface,
    required this.primarySurface,
    required this.cardBackground,
    required this.primary,
    required this.primaryHover,
    required this.success,
    required this.warning,
    required this.error,
    required this.divider,
  }) : _background = background;

  /// Claude Design System 浅色模式。
  factory AgentColors.light() => const AgentColors._(
    background: Color(0xFFFAF9F5),
    textPrimary: Color(0xFF141413),
    textSecondary: Color(0xFF55524D),
    textDisabled: Color(0xFFB0AEA5),
    surface: Color(0xFFFAF9F5),
    primarySurface: Color(0xFFF3F0EA),
    cardBackground: Color(0xFFFAF9F5),
    primary: Color(0xFFD97757),
    primaryHover: Color(0xFFC1633F),
    success: Color(0xFF788C5D),
    warning: Color(0xFFD97757),
    error: Color(0xFFC1633F),
    divider: Color(0xFFE8E6DC),
  );

  /// Claude Design System 深色模式。
  factory AgentColors.dark() => const AgentColors._(
    background: Color(0xFF141413),
    textPrimary: Color(0xFFFAF9F5),
    textSecondary: Color(0xFFB5B2AB),
    textDisabled: Color(0xFF6E6B63),
    surface: Color(0xFF141413),
    primarySurface: Color(0xFF252522),
    cardBackground: Color(0xFF141413),
    primary: Color(0xFFD97757),
    primaryHover: Color(0xFFE08C6D),
    success: Color(0xFF788C5D),
    warning: Color(0xFFD97757),
    error: Color(0xFFE08C6D),
    divider: Color(0xFF2E2C28),
  );

  static AgentColors of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Theme.of(context).extension<AgentColors>() ??
        (brightness == Brightness.dark
            ? AgentColors.dark()
            : AgentColors.light());
  }

  @override
  AgentColors copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? background,
    Color? surface,
    Color? primarySurface,
    Color? cardBackground,
    Color? primary,
    Color? primaryHover,
    Color? success,
    Color? warning,
    Color? error,
    Color? divider,
  }) {
    return AgentColors._(
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      background: background ?? _background,
      surface: surface ?? this.surface,
      primarySurface: primarySurface ?? this.primarySurface,
      cardBackground: cardBackground ?? this.cardBackground,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      divider: divider ?? this.divider,
    );
  }

  @override
  AgentColors lerp(ThemeExtension<AgentColors>? other, double t) {
    if (other is! AgentColors) return this;
    return AgentColors._(
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      background: Color.lerp(_background, other._background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      primarySurface: Color.lerp(primarySurface, other.primarySurface, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}
