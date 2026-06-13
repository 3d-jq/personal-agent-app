import 'package:flutter/material.dart';

/// Global animated background color, driven by theme transition in App.
final ValueNotifier<Color> animatedBgNotifier = ValueNotifier<Color>(const Color(0xFFF3F3F3));

/// Notion-inspired warm gray color system.
/// No pure black, no pure white — every gray leans warm.
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
        background: Color(0xFFF3F3F3),
        textPrimary: Color(0xFF37352F),
        textSecondary: Color(0xFF9B9A97),
        textDisabled: Color(0xFFC3C2BF),
        surface: Color(0xFFFFFFFF),
        primarySurface: Color(0xFFF7F6F3),
        cardBackground: Color(0xFFFFFFFF),
        success: Color(0xFF0F7B6C),
        warning: Color(0xFFDFAB01),
        error: Color(0xFFEB5757),
        divider: Color(0xFFEBECED),
      );

  factory AgentColors.dark() => const AgentColors._(
        background: Color(0xFF1A1A18),
        textPrimary: Color(0xFFE8E6E1),
        textSecondary: Color(0xFF9B9A97),
        textDisabled: Color(0xFF6B6A67),
        surface: Color(0xFF2C2C2A),
        primarySurface: Color(0xFF37352F),
        cardBackground: Color(0xFF2C2C2A),
        success: Color(0xFF2DD4BF),
        warning: Color(0xFFFBBF24),
        error: Color(0xFFF87171),
        divider: Color(0xFF3A3A38),
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
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}
