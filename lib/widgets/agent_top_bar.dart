import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/agent_colors.dart';

class AgentTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? dropdownText;
  final Widget? trailing;
  final Widget? afterMenu;

  const AgentTopBar({
    super.key,
    this.title,
    this.dropdownText,
    this.trailing,
    this.afterMenu,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    // Apple HIG：毛玻璃材质导航栏
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: colors.background.withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: colors.divider,
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.only(top: topPadding),
          child: SizedBox(
            height: 64,
            child: Stack(
              children: [
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Scaffold.of(context).openDrawer();
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            PhosphorIconsRegular.list,
                            size: 20,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (afterMenu != null) ...[
                        const SizedBox(width: 8),
                        afterMenu!,
                      ],
                    ],
                  ),
                ),
                if (title != null)
                  Center(
                    child: dropdownText != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primarySurface,
                              border: Border.all(color: colors.divider, width: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  dropdownText!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  PhosphorIconsRegular.caretDown,
                                  size: 18,
                                  color: colors.textPrimary,
                                ),
                              ],
                            ),
                          )
                        : Text(
                            title!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                  ),
                if (trailing != null)
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(child: trailing!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64 + 48);
}
