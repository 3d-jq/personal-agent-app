import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/agent_colors.dart';
import '../core/design_tokens.dart';

/// 公共区域标题
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final AgentColors nc;

  const SectionHeader({
    super.key,
    required this.title,
    required this.nc,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpaceToken.lg,
        SpaceToken.lg,
        SpaceToken.lg,
        SpaceToken.sm,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: FontToken.caption,
              fontWeight: WeightToken.medium,
              color: nc.textSecondary,
            ),
          ),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 6),
            Text(
              '($count)',
              style: TextStyle(fontSize: FontToken.small, color: nc.textDisabled),
            ),
          ],
        ],
      ),
    );
  }
}

/// 公共圆角卡片（无内边距，调用方自行控制内容 padding）
///
/// 旧版仅用 0.5px 边框、无阴影。新设计请用 [ElevatedCard]。
class RoundedCard extends StatelessWidget {
  final AgentColors nc;
  final List<Widget> children;

  const RoundedCard({
    super.key,
    required this.nc,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: nc.bgSubtle,
        borderRadius: BorderRadius.circular(RadiusToken.md),
        border: Border.all(color: nc.divider, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

/// 带阴影的浮起卡片（v2 统一卡片）。
///
/// `surface` 底 + `shadowSm` + 可选 0.5px `divider` 边框；圆角 [RadiusToken.md]。
class ElevatedCard extends StatelessWidget {
  final AgentColors nc;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool bordered;
  final List<BoxShadow>? shadow;
  final BorderRadius? borderRadius;

  const ElevatedCard({
    super.key,
    required this.nc,
    required this.child,
    this.padding,
    this.bordered = true,
    this.shadow,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(RadiusToken.md),
        border: bordered ? Border.all(color: nc.divider, width: 0.5) : null,
        boxShadow: shadow ?? nc.shadowSm,
      ),
      child: child,
    );
  }
}

/// 公共添加菜单项
class AddMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final AgentColors nc;
  final VoidCallback onTap;

  const AddMenuItem({
    super.key,
    required this.icon,
    required this.nc,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpaceToken.lg,
            vertical: SpaceToken.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: nc.primary),
              const SizedBox(width: SpaceToken.md),
              Text(
                label,
                style: TextStyle(fontSize: FontToken.body, color: nc.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 公共添加菜单弹窗
class AddMenuSheet extends StatelessWidget {
  final AgentColors nc;
  final List<AddMenuItem> items;

  const AddMenuSheet({
    super.key,
    required this.nc,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: SpaceToken.lg,
        right: SpaceToken.lg,
        bottom: MediaQuery.of(context).padding.bottom + SpaceToken.lg,
      ),
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(RadiusToken.lg),
        boxShadow: nc.shadowMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: SpaceToken.sm),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: nc.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 0.5, color: nc.divider, indent: SpaceToken.lg),
            items[i],
          ],
          const SizedBox(height: SpaceToken.sm),
        ],
      ),
    );
  }
}

/// 公通用于显示添加菜单
void showAddMenu(BuildContext context, AgentColors nc, List<AddMenuItem> items) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => AddMenuSheet(nc: nc, items: items),
  );
}

/// 统一顶部导航栏（Apple 毛玻璃风格，可配置）。
///
/// 替代全库散落的 `AppBar`。支持 `leading` / `title` / `actions`，
/// 毛玻璃 `blur 20` + 半透明 `background(.82)` + 底部 0.5px 发丝线。
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final bool useGlass;
  final double height;

  const AppTopBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.bottom,
    this.centerTitle = true,
    this.useGlass = true,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final top = MediaQuery.of(context).padding.top;
    final Widget? titleChild =
        titleWidget ?? (title != null ? _titleText(nc) : null);

    late final Widget row;
    if (centerTitle) {
      // 标题在整条栏宽内居中（与单聊 AgentTopBar 一致）；
      // 关键：标题绘制在底层，leading / actions 浮在顶层，避免长标题盖住返回键；
      // 同时给标题加对称左右留白（取左右控件所需最大宽度），保证整宽居中且不重叠。
      final double leftNeed = leading != null ? 56.0 : 0.0;
      final double rightNeed = actions != null ? 12.0 + actions!.length * 44.0 : 0.0;
      final double reserve = leftNeed > rightNeed ? leftNeed : rightNeed;
      row = Stack(
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: reserve),
              child: titleChild,
            ),
          ),
          if (leading != null)
            Positioned(
              left: SpaceToken.md,
              top: 0,
              bottom: 0,
              child: Center(child: leading),
            ),
          if (actions != null)
            Positioned(
              right: SpaceToken.md,
              top: 0,
              bottom: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                ),
              ),
            ),
        ],
      );
    } else {
      row = Row(
        children: [
          if (leading != null)
            Padding(
              padding: const EdgeInsets.only(left: SpaceToken.md),
              child: leading,
            ),
          if (titleWidget != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: SpaceToken.lg),
                child: titleWidget,
              ),
            )
          else if (title != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: SpaceToken.lg),
                child: _titleText(nc),
              ),
            )
          else
            const Spacer(),
          if (actions != null)
            Padding(
              padding: const EdgeInsets.only(right: SpaceToken.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!,
              ),
            ),
        ],
      );
    }

    final bar = Container(
      decoration: BoxDecoration(
        color: nc.background.withValues(alpha: useGlass ? 0.82 : 1.0),
        border: Border(bottom: BorderSide(color: nc.divider, width: 0.5)),
      ),
      child: bottom == null
          ? Padding(
              padding: EdgeInsets.only(top: top),
              child: SizedBox(height: height, child: row),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: top),
                  child: SizedBox(height: height, child: row),
                ),
                bottom!,
              ],
            ),
    );
    if (!useGlass) return bar;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: bar,
      ),
    );
  }

  Widget _titleText(AgentColors nc) => Text(
        title!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: FontToken.headline,
          fontWeight: WeightToken.semibold,
          color: nc.textPrimary,
        ),
      );

  @override
  Size get preferredSize {
    final top = WidgetsBinding.instance.platformDispatcher.views.firstOrNull?.padding.top ?? 44;
    final bottomH = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(height + top + bottomH);
  }
}

/// 统一列表项（v2）。
///
/// `leading` + `title` + `subtitle` + `trailing`；按压为 `fillTertiary` 高亮（无 Android 水波纹）。
class AppListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const AppListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpaceToken.lg,
        vertical: SpaceToken.md,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: SpaceToken.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: FontToken.body,
                    fontWeight: WeightToken.medium,
                    color: nc.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: FontToken.small,
                      color: nc.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    final tile = onTap != null
        ? InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            highlightColor: nc.fillTertiary,
            child: content,
          )
        : content;

    return Column(
      children: [
        tile,
        if (showDivider)
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: nc.divider,
            indent: leading != null ? SpaceToken.lg + 40 : SpaceToken.lg,
          ),
      ],
    );
  }
}

/// 统一按钮（v2）。
enum AppButtonVariant { primary, secondary, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final double? height;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.height = 48,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final fg = variant == AppButtonVariant.primary ? nc.onPrimary : nc.primary;
    final bg = switch (variant) {
      AppButtonVariant.primary => nc.primary,
      AppButtonVariant.secondary => nc.surface,
      AppButtonVariant.ghost => Colors.transparent,
    };
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: SpaceToken.sm),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: FontToken.body,
            fontWeight: WeightToken.semibold,
            color: fg,
          ),
        ),
      ],
    );

    final btn = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: SpaceToken.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusToken.md),
          side: variant == AppButtonVariant.secondary
              ? BorderSide(color: nc.divider)
              : BorderSide.none,
        ),
      ),
      child: child,
    );

    return SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: btn,
    );
  }
}

/// 统一头像（v2）。
///
/// 首字母 + 品牌蓝→hover 渐变；圆角 squircle 感；可选 `ring`（白色描边 + 阴影）。
class AppAvatar extends StatelessWidget {
  final String? name;
  final double size;
  final Color? backgroundColor;
  final bool ring;

  const AppAvatar({
    super.key,
    this.name,
    this.size = 40,
    this.backgroundColor,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final safeName = name?.trim() ?? '';
    final initials = safeName.isNotEmpty ? safeName[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: backgroundColor == null
            ? LinearGradient(colors: [nc.primary, nc.primaryHover])
            : null,
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: ring ? Border.all(color: nc.surface, width: 2) : null,
        boxShadow: ring ? nc.shadowSm : null,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: WeightToken.semibold,
          ),
        ),
      ),
    );
  }
}
