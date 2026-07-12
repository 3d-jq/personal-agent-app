import 'package:flutter/material.dart';

import 'package:personal_agent_app/core/app_animations.dart';
import 'package:personal_agent_app/models/chat_message.dart';

/// 计算「n 条新消息」未读数（纯函数，单聊/群聊共用，避免算法重复）。
///
/// 计算规则（贴近微信）：
/// - [userScrolledUp] 为 false 时恒为 0（用户没离开底部就不算未读）；
/// - 任何 [ChatMessage.seq] 大于 [anchorSeq] 的消息都算 1 条未读（新一轮新气泡）；
/// - 若没有更新的消息对象，但锚点那条本身仍在流式变长（同一消息内容增长），
///   也计为 1 条未读——用户上滑离开它后它继续吐字，应提示「1 条新消息」；
/// - [messages] 为空时恒为 0。
int computeUnreadCount(
  List<ChatMessage> messages,
  int anchorSeq,
  int anchorLen,
  bool userScrolledUp,
) {
  if (!userScrolledUp) return 0;
  if (messages.isEmpty) return 0;
  int count = 0;
  for (final m in messages) {
    if (m.seq > anchorSeq) count++;
  }
  if (count == 0) {
    final last = messages.last;
    if (last.seq == anchorSeq && last.text.length > anchorLen) count = 1;
  }
  return count.clamp(0, 999);
}

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

  /// 用户上滑离开底部那一刻的「已读锚点」：
  /// - [anchorSeq]：当时最后一条消息的 seq；
  /// - [anchorLen]：当时锚点消息的内容长度。
  /// 「n 条新消息」浮条据此判断自用户离开后底部是否出现了更新的内容
  /// （含正在流式变长的那条，计为 1 条），而非旧实现里单纯的「消息条数差」——
  /// 旧算法因 AI 流式回复是同一消息对象变长、条数不变而恒为 0，是死功能。
  int anchorSeq = -1;
  int anchorLen = 0;

  /// 程序主动触发的滚动（点击回到底部 / 流式自动贴底）期间为 true，
  /// 避免 onScroll 把"自己的位移"误判成用户上滑而污染状态。
  bool autoScrolling = false;

  /// Drawer 打开时为 true：暂停自动贴底滚动，避免每帧 jumpTo 与 Drawer 动画抢主 isolate。
  bool drawerOpen = false;

  /// 当前消息条数（由使用方提供，供上滑检测用）。
  int get messageCount;

  /// 当前最后一条消息（由使用方提供），用于记录上滑「已读锚点」。
  ChatMessage? get lastMessage;

  /// 全部消息（由使用方提供），用于计算「n 条新消息」未读数。
  List<ChatMessage> get allMessages;

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
        final last = lastMessage;
        if (last != null) {
          anchorSeq = last.seq;
          anchorLen = last.text.length;
        } else {
          anchorSeq = -1;
          anchorLen = 0;
        }
      }
    }
  }

  /// 「n 条新消息」未读数：自用户上滑锚点以来底部新增的更新内容条数。
  ///
  /// 计算规则（贴近微信）：
  /// - 任何 [ChatMessage.seq] 大于锚点的消息都算 1 条未读（新一轮新气泡）；
  /// - 若没有更新消息对象，但锚点那条本身仍在流式变长（同一消息内容增长），
  ///   也计为 1 条未读——用户上滑离开它后它继续吐字，应提示「1 条新消息」；
  /// - 用户未上滑（[userScrolledUp] 为 false）时恒为 0。
  int unreadCount() =>
      computeUnreadCount(allMessages, anchorSeq, anchorLen, userScrolledUp);

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
  void jumpToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  /// 跳到底部 + 自动重试：ListView.builder 的 lazy 构建可能导致
  /// maxScrollExtent 在多帧之后才稳定；单次 jumpTo 容易跳到旧的半路位置。
  /// 每帧检查一次，若底部又扩展了则再跳，直到稳定或耗尽重试次数。
  void _jumpToBottom({int retries = 8}) {
    if (!mounted || retries <= 0) return;
    if (!scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _jumpToBottom(retries: retries - 1));
      return;
    }
    userScrolledUp = false;
    anchorSeq = -1;
    anchorLen = 0;
    final max = scrollController.position.maxScrollExtent;
    scrollController.jumpTo(max);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients || !mounted) return;
      final newMax = scrollController.position.maxScrollExtent;
      if (newMax > max) {
        _jumpToBottom(retries: retries - 1);
      }
    });
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
    anchorSeq = -1;
    anchorLen = 0;
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
