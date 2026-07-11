import 'package:flutter/material.dart';

import '../controllers/chat_controller.dart';

/// 聊天控制器缓存（微信级 L8 页面缓存）。
///
/// 同一会话的 [ChatController] 跨页面进出复用时只创建一次：
/// - 再次进入已打开过的会话时，直接复用缓存的控制器，消息已在内存、
///   无需重新从 DB 加载，进入瞬间无白屏/无重载闪烁。
/// - 退出时由本缓存持有控制器（ChatScreen 不 dispose 它），仅记录滚动位置。
///
/// 新建会话（sessionId 为 null）不缓存，每次创建新实例。
class ChatControllerCache {
  ChatControllerCache._();
  static final ChatControllerCache instance = ChatControllerCache._();

  final Map<String, ChatController> _cache = {};

  /// 取得指定会话的控制器：已缓存则复用，否则新建并缓存。
  /// [onNeedScroll] 在复用时会重新绑定到新页面的滚屏回调（旧页面已销毁）。
  ChatController obtain(String? sessionId, {VoidCallback? onNeedScroll}) {
    if (sessionId == null) {
      return ChatController(initialSessionId: null, onNeedScroll: onNeedScroll);
    }
    final controller = _cache.putIfAbsent(
      sessionId,
      () => ChatController(initialSessionId: sessionId, onNeedScroll: onNeedScroll),
    );
    controller.onNeedScroll = onNeedScroll;
    return controller;
  }

  /// 主动移除（如会话被删除）。
  void evict(String sessionId) {
    _cache.remove(sessionId);
  }

  /// 清空全部（如登出/重置）。
  void clear() {
    for (final c in _cache.values) {
      c.dispose();
    }
    _cache.clear();
  }
}
