import 'package:flutter/material.dart';

/// Apple Human Interface Guidelines 设计风格配色。
///
/// 浅色 / 深色模式，遵循 Apple 原生系统设计。
/// v2 重设计：补充阴影层级（shadowSm/Md/Lg）、文字三档、按压填充、
/// 次级区分隔背景，并保留全部旧字段以保证向后兼容。
class AgentColors extends ThemeExtension<AgentColors> {
  // ── Text ──
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color onPrimary;

  // ── Backgrounds ──
  final Color _background;
  final Color surface;
  final Color surfaceSecondary;
  final Color bgSubtle;
  final Color primarySurface;
  final Color cardBackground;
  final Color fillTertiary;

  // ── Brand / Accent ──
  final Color primary;
  final Color primaryHover;
  final Color brandSoft;

  // ── Functional ──
  final Color success;
  final Color warning;
  final Color error;

  // ── Dividers & borders ──
  final Color divider;

  // ── Elevation / shadow ──
  final Color shadowColor;
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowLg;

  Color get background => _background;
  Color get inputBg => bgSubtle;
  Color get chipBg => primarySurface;
  Color get chipBorder => divider;
  Color get navBg => surface;
  Color get cardBg => cardBackground;
  Color get iconBtnBg => primarySurface;
  Color get groupBg => surfaceSecondary;

  const AgentColors._({
    required Color background,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.onPrimary,
    required this.surface,
    required this.surfaceSecondary,
    required this.bgSubtle,
    required this.primarySurface,
    required this.cardBackground,
    required this.fillTertiary,
    required this.primary,
    required this.primaryHover,
    required this.brandSoft,
    required this.success,
    required this.warning,
    required this.error,
    required this.divider,
    required this.shadowColor,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
  }) : _background = background;

  /// Apple HIG 浅色模式。
  factory AgentColors.light() => const AgentColors._(
    background: Color(0xFFFAFAFA),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0x993C3C43),
    textTertiary: Color(0x4D3C3C43),
    textDisabled: Color(0x333C3C43),
    onPrimary: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFF4F4F4),
    bgSubtle: Color(0xFFF4F4F4),
    primarySurface: Color(0xFFF4F4F4),
    cardBackground: Color(0xFFF4F4F4),
    fillTertiary: Color(0x143C3C43),
    primary: Color(0xFF007AFF),
    primaryHover: Color(0xFF0056CC),
    brandSoft: Color(0xFFE6F1FB),
    success: Color(0xFF34C759),
    warning: Color(0xFFFF9500),
    error: Color(0xFFFF3B30),
    divider: Color(0x333C3C43),
    shadowColor: Color(0x1A000000),
    shadowSm: <BoxShadow>[
      BoxShadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0x0A000000)),
      BoxShadow(offset: Offset(0, 1), blurRadius: 1, color: Color(0x07000000)),
    ],
    shadowMd: <BoxShadow>[
      BoxShadow(offset: Offset(0, 4), blurRadius: 12, color: Color(0x0F000000)),
      BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x0A000000)),
    ],
    shadowLg: <BoxShadow>[
      BoxShadow(offset: Offset(0, 12), blurRadius: 32, color: Color(0x1A000000)),
      BoxShadow(offset: Offset(0, 4), blurRadius: 8, color: Color(0x0A000000)),
    ],
  );

  /// Apple HIG 深色模式。
  factory AgentColors.dark() => const AgentColors._(
    background: Color(0xFF000000),
    textPrimary: Color(0xFFF2F2F7),
    textSecondary: Color(0x99EBEBF5),
    textTertiary: Color(0x66EBEBF5),
    textDisabled: Color(0x33EBEBF5),
    onPrimary: Color(0xFFFFFFFF),
    surface: Color(0xFF1C1C1C),
    surfaceSecondary: Color(0xFF2C2C2C),
    bgSubtle: Color(0xFF1C1C1C),
    primarySurface: Color(0xFF2C2C2C),
    cardBackground: Color(0xFF1C1C1C),
    fillTertiary: Color(0x1FECECF5),
    primary: Color(0xFF0A84FF),
    primaryHover: Color(0xFF409CFF),
    brandSoft: Color(0x2A0A84FF),
    success: Color(0xFF30D158),
    warning: Color(0xFFFF9F0A),
    error: Color(0xFFFF453A),
    divider: Color(0x33EBEBF5),
    shadowColor: Color(0x80000000),
    shadowSm: <BoxShadow>[
      BoxShadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0x80000000)),
    ],
    shadowMd: <BoxShadow>[
      BoxShadow(offset: Offset(0, 8), blurRadius: 24, color: Color(0x99000000)),
    ],
    shadowLg: <BoxShadow>[
      BoxShadow(offset: Offset(0, 16), blurRadius: 40, color: Color(0xB3000000)),
    ],
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
    Color? background,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? onPrimary,
    Color? surface,
    Color? surfaceSecondary,
    Color? bgSubtle,
    Color? primarySurface,
    Color? cardBackground,
    Color? fillTertiary,
    Color? primary,
    Color? primaryHover,
    Color? brandSoft,
    Color? success,
    Color? warning,
    Color? error,
    Color? divider,
    Color? shadowColor,
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? shadowLg,
  }) {
    return AgentColors._(
      background: background ?? _background,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      onPrimary: onPrimary ?? this.onPrimary,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      bgSubtle: bgSubtle ?? this.bgSubtle,
      primarySurface: primarySurface ?? this.primarySurface,
      cardBackground: cardBackground ?? this.cardBackground,
      fillTertiary: fillTertiary ?? this.fillTertiary,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      brandSoft: brandSoft ?? this.brandSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      divider: divider ?? this.divider,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
    );
  }

  @override
  AgentColors lerp(ThemeExtension<AgentColors>? other, double t) {
    if (other is! AgentColors) return this;
    return AgentColors._(
      background: Color.lerp(_background, other._background, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSecondary:
          Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      bgSubtle: Color.lerp(bgSubtle, other.bgSubtle, t)!,
      primarySurface: Color.lerp(primarySurface, other.primarySurface, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      fillTertiary: Color.lerp(fillTertiary, other.fillTertiary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      shadowSm: BoxShadow.lerpList(shadowSm, other.shadowSm, t)!,
      shadowMd: BoxShadow.lerpList(shadowMd, other.shadowMd, t)!,
      shadowLg: BoxShadow.lerpList(shadowLg, other.shadowLg, t)!,
    );
  }
}
