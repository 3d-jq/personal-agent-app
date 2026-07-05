import 'package:flutter/material.dart';

/// Apple Human Interface Guidelines 设计风格配色。
///
/// 浅色 / 深色模式，遵循 Apple 原生系统设计。
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

  /// Apple HIG 浅色模式。
  factory AgentColors.light() => const AgentColors._(
    background: Color(0xFFF2F2F7),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0x993C3C43),
    textDisabled: Color(0x333C3C43),
    surface: Color(0xFFFFFFFF),
    primarySurface: Color(0xFFF2F2F7),
    cardBackground: Color(0xFFFFFFFF),
    primary: Color(0xFF007AFF),
    primaryHover: Color(0xFF0056CC),
    success: Color(0xFF34C759),
    warning: Color(0xFFFF9500),
    error: Color(0xFFFF3B30),
    divider: Color(0x333C3C43),
  );

  /// Apple HIG 深色模式。
  factory AgentColors.dark() => const AgentColors._(
    background: Color(0xFF000000),
    textPrimary: Color(0xFFF2F2F7),
    textSecondary: Color(0x99EBEBF5),
    textDisabled: Color(0x33EBEBF5),
    surface: Color(0xFF1C1C1E),
    primarySurface: Color(0xFF2C2C2E),
    cardBackground: Color(0xFF1C1C1E),
    primary: Color(0xFF0A84FF),
    primaryHover: Color(0xFF409CFF),
    success: Color(0xFF30D158),
    warning: Color(0xFFFF9F0A),
    error: Color(0xFFFF453A),
    divider: Color(0x33EBEBF5),
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
