import 'package:flutter/material.dart';

import 'package:personal_agent_app/core/app_animations.dart';

/// 聊天列表滚动行为：贴底 / 回到底部 / 上滑浮条 / 抽屉期间暂停等。
///
/// 从 [_ChatScreenState] 抽出滚动相关的字段与方法，避免 State 类过长。
/// 使用方需：
/// - `with ChatScrollMixin` 并声明 [messageCount]（当前消息条数）；
/// - 在 initState 里 `scrollController.addListener(onScroll)`、
///   dispose 里 `scrollController.removeListener(onScroll)` + `scrollController.dispose()`；
/// - 把 build / didChangeMetrics 中对滚动状态的引用改用本 mixin 的公有字段。
mixin ChatScrollMixin<T extends StatefulWidget> on State<T> {
  /// 实际持有的滚动控制器（供 build / initState / dispose 访问）。
  final ScrollController scrollController = ScrollController();

  /// 是否显示「回到底部」浮条。
  bool showScrollBottom = false;

  /// 用户是否上滑看过历史（用于「n 条新消息」浮条与暂停自动贴底）。
  bool userScrolledUp = false;

  /// 用户上滑时的消息数，用于计算「n 条新消息」浮条。
  int msgCountWhenScrolledUp = 0;

  /// 程序主动触发的滚动（点击回到底部 / 流式自动贴底）期间为 true，
  /// 避免 onScroll 把"自己的位移"误判成用户上滑而污染状态。
  bool autoScrolling = false;

  /// Drawer 打开时为 true：暂停自动贴底滚动，避免每帧 jumpTo 与 Drawer 动画抢主 isolate。
  bool drawerOpen = false;

  /// 当前消息条数（由使用方提供，供上滑检测用）。
  int get messageCount;

  bool _pendingScroll = false;

  /// 滚动回调：区分用户上滑与程序滚动，更新浮条与已读计数。
  void onScroll() {
    // 程序主动滚动期间忽略，避免误判用户上滑
    if (!scrollController.hasClients || autoScrolling) return;
    final max = scrollController.position.maxScrollExtent;
    final current = scrollController.position.pixels;
    final distFromBottom = max - current;
    final shouldShow = distFromBottom > 120;
    if (shouldShow != showScrollBottom) {
      setState(() => showScrollBottom = shouldShow);
    }
    if (distFromBottom > 60) {
      if (!userScrolledUp) {
        userScrolledUp = true;
        msgCountWhenScrolledUp = messageCount;
      }
    }
  }

  /// 流式期间实时贴底：下一帧布局完成后 jump 到末尾，消除 50ms 节流造成的「定期猛跳」。
  /// 用 [_pendingScroll] 去重，避免每个流式 token 都注册一次 postFrame 回调而堆积。
  void scrollDown() {
    // Drawer 打开时暂停自动贴底：避免每帧 jumpTo 与 Drawer 打开动画抢主 isolate
    if (drawerOpen) return;
    if (userScrolledUp || autoScrolling || _pendingScroll) return;
    _pendingScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScroll = false;
      if (!scrollController.hasClients || userScrolledUp || autoScrolling) return;
      autoScrolling = true;
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      autoScrolling = false;
    });
  }

  /// 进入/切换会话后定位到最新消息（聊天软件惯例：进会话即见最新）。
  /// 必须等列表布局完成（maxScrollExtent 已知）再跳，故用 post-frame 回调；
  /// 列表尚未挂载（hasClients 为 false）时递归延一帧重试，确保最终跳到底部。
  void jumpToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) => jumpToLatestNow());
  }

  void jumpToLatestNow() {
    if (!mounted) return;
    if (!scrollController.hasClients) {
      // 列表尚未挂载（如仍在骨架屏 / 切换中），下一帧再试一次
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpToLatestNow());
      return;
    }
    userScrolledUp = false;
    scrollController.jumpTo(scrollController.position.maxScrollExtent);
  }

  /// 平滑回到底部：用于点击「回到底部」按钮。
  /// 复位 userScrolledUp 让流式自动贴底能恢复。
  ///
  /// 【顺滑 + 无白屏】距底不超过 cacheExtent 的 ~80%（约 3200px≈4 屏）时直接整体用
  /// 原生 `animateTo` 平滑滚动：该范围内气泡已由 cacheExtent 预构建，沿途无白屏、无
  /// 突兀跳变，最跟手。仅当用户在极远处（>4 屏）点回到底部，才先瞬时 jumpTo 到
  /// 「底部前约 1.5 屏」（只构建最后一屏气泡，避免 animateTo 一路白屏），再对最后一
  /// 小段做平滑动画收尾。
  void scrollToBottom() {
    if (!scrollController.hasClients) return;
    userScrolledUp = false;
    final pos = scrollController.position;
    final viewport = pos.viewportDimension;
    final max = pos.maxScrollExtent;
    // 先置位程序滚动守卫，使下方预跳 jumpTo 不被 onScroll 误判为用户上滑/重复 setState
    autoScrolling = true;
    const cacheExtentPx = 4000.0; // 与 _MessageList cacheExtent 对齐
    final smoothLimit = (cacheExtentPx * 0.8).clamp(0.0, max);
    if (max - scrollController.offset > smoothLimit) {
      // 超远：先瞬时跳到「底部前约 1.5 屏」，只构建最后一屏，避免 animateTo 沿途白屏
      final preJump = (max - viewport * 1.5).clamp(0.0, max);
      scrollController.jumpTo(preJump);
    }
    scrollController
        .animateTo(
          max,
          duration: AppDurations.standard,
          curve: AppCurves.standard,
        )
        .then((_) => autoScrolling = false)
        .catchError((_) => autoScrolling = false);
  }
}
