import 'package:flutter/material.dart';

/// 极简对话式设计令牌（Design Tokens）。
///
/// 集中管理圆角、间距、字号、字重、动画时长等基础尺度，
/// 替代散落在各组件中的 magic number，保证全 App 视觉节奏一致。
/// 颜色 / 阴影见 [AgentColors]（含浅色与暗色双模）。

/// 圆角（基于 4pt 栅格）。
class RadiusToken {
  RadiusToken._();

  /// 小标签 / chip
  static const double sm = 8;

  /// 卡片 / 按钮 / 输入框
  static const double md = 12;

  /// 底部 Sheet / Modal 顶部
  static const double lg = 16;

  /// 大浮层 / 引导卡
  static const double xl = 20;

  /// 用户消息气泡（现状保留）
  static const double bubble = 18;

  /// 底部输入胶囊 / 头像组
  static const double pill = 24;

  /// 圆形（头像 / 圆形按钮）
  static const double full = 9999;
}

/// 间距（4pt 栅格：4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 / 64）。
class SpaceToken {
  SpaceToken._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double x2 = 24;
  static const double x05 = 40;
  static const double x3 = 32;
  static const double x4 = 48;
  static const double x5 = 64;
}

/// 字号阶梯（基于 4pt 栅格与 1.2–1.5 行高比）。
class FontToken {
  FontToken._();

  /// 微型（Tab 角标）
  static const double micro = 11;

  /// 辅助（时间 / 标签）
  static const double caption = 12;

  /// 次要（步骤状态 / 说明）
  static const double small = 13;

  /// 正文（用户气泡 / 列表预览）
  static const double body = 15;

  /// 大正文
  static const double bodyLg = 17;

  /// 标题（卡片标题 / 会话名）
  static const double title = 17;

  /// 大标题（页面主标题）
  static const double headline = 20;

  /// 区块标题
  static const double title2 = 22;

  /// 超大标题
  static const double display = 28;

  /// 极少用大标题
  static const double largeTitle = 34;
}

/// 字重（极简克制但保留层级：常规 → 粗）。
class WeightToken {
  WeightToken._();

  /// 常规
  static const FontWeight regular = FontWeight.w400;

  /// 中粗
  static const FontWeight medium = FontWeight.w500;

  /// 半粗（标题 / 按钮）
  static const FontWeight semibold = FontWeight.w600;

  /// 粗（大标题 / 强调）
  static const FontWeight bold = FontWeight.w700;
}

/// 动画时长。
class MotionToken {
  MotionToken._();

  /// 微交互（hover / 按压 / 按钮态切换）
  static const Duration fast = Duration(milliseconds: 150);

  /// 页面 / 浮层进出
  static const Duration normal = Duration(milliseconds: 250);

  /// 大转场 / 向导
  static const Duration slow = Duration(milliseconds: 350);

  /// 标准缓动曲线
  static const Curve standard = Curves.easeOutCubic;
}

/// 统一按压态透明度（极克制，靠背景色微变而非位移/阴影）。
const double kPressedOpacity = 0.85;

/// 最小触控目标边长（WCAG / 移动可用性）。
const double kMinTarget = 44;
