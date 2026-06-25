import 'package:flutter/material.dart';

/// Global animated background color, driven by theme transition in App.
final ValueNotifier<Color> animatedBgNotifier = ValueNotifier<Color>(
  const Color(0xFFF2F2F7),
);

/// iOS-inspired color system.
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
    required this.success,
    required this.warning,
    required this.error,
    required this.divider,
  }) : _background = background;

  /// Returns the animated background color (smooth theme transition).
  Color get background => animatedBgNotifier.value;

  /// Raw static background color, bypassing animation. Used by theme switcher.
  Color get staticBackground => _background;

  factory AgentColors.light() => const AgentColors._(
    background: Color(0xFFF2F2F7), // iOS System Gray 6
    textPrimary: Color(0xFF000000),
    textSecondary: Color.fromRGBO(0, 0, 0, 0.55),
    textDisabled: Color.fromRGBO(0, 0, 0, 0.25),
    surface: Color(0xFFFFFFFF),
    primarySurface: Color(0xFFF2F2F7),
    cardBackground: Color(0xFFFFFFFF),
    primary: Color(0xFF007AFF), // iOS System Blue
    success: Color(0xFF34C759), // iOS System Green
    warning: Color(0xFFFF9500), // iOS System Orange
    error: Color(0xFFFF3B30), // iOS System Red
    divider: Color.fromRGBO(60, 60, 67, 0.12),
  );

  factory AgentColors.dark() => const AgentColors._(
    background: Color(0xFF000000),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color.fromRGBO(255, 255, 255, 0.55),
    textDisabled: Color.fromRGBO(255, 255, 255, 0.25),
    surface: Color.fromRGBO(28, 28, 30, 0.95),
    primarySurface: Color.fromRGBO(28, 28, 30, 0.95),
    cardBackground: Color.fromRGBO(28, 28, 30, 0.95),
    primary: Color(0xFF0A84FF), // iOS Dark Blue
    success: Color(0xFF30D158), // iOS Dark Green
    warning: Color(0xFFFF9F0A), // iOS Dark Orange
    error: Color(0xFFFF453A), // iOS Dark Red
    divider: Color.fromRGBO(84, 84, 88, 0.12),
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