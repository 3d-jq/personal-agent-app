import 'package:flutter/material.dart';

/// Material 3 color system — derived from ColorScheme.fromSeed.
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

  // ── Brand ──
  final Color primary;

  // ── Functional ──
  final Color success;
  final Color warning;
  final Color error;

  // ── Dividers & borders ──
  final Color divider;

  Color get inputBg => primarySurface;
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
    required this.success,
    required this.warning,
    required this.error,
    required this.divider,
  }) : _background = background;

  /// Returns the background color from the current theme.
  Color get background => _background;

  /// Build from a generated ColorScheme.
  factory AgentColors.fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return AgentColors._(
      background: scheme.surface,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurface.withValues(alpha: 0.55),
      textDisabled: scheme.onSurface.withValues(alpha: 0.25),
      surface: scheme.surface,
      primarySurface: scheme.surfaceContainerLow,
      cardBackground: scheme.surface,
      primary: scheme.primary,
      success: Colors.green.shade700,
      warning: Colors.orange.shade900,
      error: scheme.error,
      divider: scheme.outlineVariant,
    );
  }

  /// Default light theme (teal). Prefer fromScheme() with a ColorScheme.
  factory AgentColors.light() => AgentColors.fromScheme(
    ColorScheme.fromSeed(seedColor: const Color(0xFF009688), brightness: Brightness.light),
  );

  /// Default dark theme (teal). Prefer fromScheme() with a ColorScheme.
  factory AgentColors.dark() => AgentColors.fromScheme(
    ColorScheme.fromSeed(seedColor: const Color(0xFF009688), brightness: Brightness.dark),
  );

  static AgentColors of(BuildContext context) =>
      Theme.of(context).extension<AgentColors>() ?? AgentColors.light();

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
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}
