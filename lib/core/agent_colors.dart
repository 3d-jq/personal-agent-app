import 'package:flutter/material.dart';

/// Notion-inspired warm gray color system.
/// No pure black, no pure white — every gray leans warm.
class AgentColors extends ThemeExtension<AgentColors> {
  // ── Text ──
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  // ── Backgrounds ──
  final Color background;
  final Color surface;
  final Color primarySurface; // hover / selected subtle tint
  final Color cardBackground;

  // ── Functional (sparing use, status only) ──
  final Color success;
  final Color warning;
  final Color error;

  // ── Dividers & borders ──
  final Color divider;

  // ── Semantic aliases (kept for backward compat, delegates to canonical names) ──
  Color get inputBg => surface;
  Color get chipBg => primarySurface;
  Color get chipBorder => divider;
  Color get navBg => surface;
  Color get cardBg => cardBackground;
  Color get iconBtnBg => primarySurface;

  const AgentColors._({
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.background,
    required this.surface,
    required this.primarySurface,
    required this.cardBackground,
    required this.success,
    required this.warning,
    required this.error,
    required this.divider,
  });

  // ── Light (Notion defaults) ──
  factory AgentColors.light() => const AgentColors._(
        // Text
        textPrimary: Color(0xFF37352F), // warm dark gray
        textSecondary: Color(0xFF9B9A97), // warm light gray
        textDisabled: Color(0xFFC3C2BF), // even lighter
        // Backgrounds
        background: Color(0xFFF3F3F3), // page bg — NEVER white
        surface: Color(0xFFFFFFFF), // card bg
        primarySurface: Color(0xFFF7F6F3), // hover / selected
        cardBackground: Color(0xFFFFFFFF),
        // Functional
        success: Color(0xFF0F7B6C),
        warning: Color(0xFFDFAB01),
        error: Color(0xFFEB5757),
        // Dividers
        divider: Color(0xFFEBECED),
      );

  // ── Dark ──
  factory AgentColors.dark() => const AgentColors._(
        textPrimary: Color(0xFFE8E6E1),
        textSecondary: Color(0xFF9B9A97),
        textDisabled: Color(0xFF6B6A67),
        background: Color(0xFF1A1A18),
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
      background: background ?? this.background,
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
      background: Color.lerp(background, other.background, t)!,
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
