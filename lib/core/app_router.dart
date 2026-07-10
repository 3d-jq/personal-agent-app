import 'package:flutter/material.dart';
import '../core/app_animations.dart';
import '../models/agent.dart';
import '../models/agent_group.dart';
import '../screens/agent_chat_screen.dart';
import '../screens/agent_contact_page.dart';
import '../screens/agent_edit_page.dart';
import '../screens/agent_home_page.dart';
import '../screens/chat_screen.dart';
import '../screens/group_edit_page.dart';
import '../screens/message_list_page.dart';
import '../services/context_doc_service.dart';
import '../widgets/about_page.dart';
import '../widgets/acknowledgement_view.dart';
import '../widgets/agent_group/group_chat_screen.dart';
import '../widgets/log_page.dart';
import '../widgets/context_docs_panel.dart';
import '../widgets/image_cache_page.dart';
import '../widgets/media_page.dart';
import '../widgets/model_settings_page.dart';
import '../widgets/notes_page.dart';
import '../widgets/reminders_page.dart';
import '../widgets/scratch_viewer.dart';
import '../widgets/search_page.dart';
import '../widgets/settings_page.dart';
import '../widgets/skill_mcp_page.dart';

/// 应用路由管理入口。
///
/// 集中所有页面跳转逻辑，避免业务代码里直接调用 [Navigator.push]。
/// 转场动画统一使用 [IosSlideRoute]（iOS 横滑视差 + 边缘返回手势）。
class AppRouter {
  AppRouter._();

  /// 通用 push，用于私有页面或一次性跳转。
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(IosSlideRoute(page: page));
  }

  /// 返回上一页。
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop<T>(result);
  }

  // ── 主页面 ──
  static Future<void> toMessages(BuildContext context) =>
      push(context, const MessageListPage());

  static Future<void> toAgentContact(BuildContext context) =>
      push(context, const AgentContactPage());

  static Future<void> toChat(BuildContext context, {String? sessionId}) =>
      push(context, ChatScreen(sessionId: sessionId));

  /// 与 Agent 单聊
  static Future<void> toAgentChat(BuildContext context, Agent agent) =>
      push(context, AgentChatScreen(agent: agent));

  // ── 侧边栏入口 ──
  static Future<void> toNotes(BuildContext context) =>
      push(context, const NotesPage());

  static Future<void> toMedia(BuildContext context) =>
      push(context, const MediaView());

  static Future<void> toReminders(BuildContext context) =>
      push(context, const RemindersView());

  static Future<void> toSkillMcp(BuildContext context) =>
      push(context, const SkillMcpPage());

  static Future<void> toSearch(BuildContext context) =>
      push(context, const SearchPage());

  static Future<void> toSettings(BuildContext context) =>
      push(context, const SettingsPage());

  // ── 设置子页 ──
  static Future<void> toModelSettings(BuildContext context) =>
      push(context, const ModelSettingsView());

  static Future<void> toImageCache(BuildContext context) =>
      push(context, const ImageCachePage());

  static Future<void> toAbout(BuildContext context) =>
      push(context, const AboutView());

  static Future<void> toLog(BuildContext context) =>
      push(context, const LogPage());

  static Future<void> toAcknowledgement(BuildContext context) =>
      push(context, const AcknowledgementView());

  // ── Agent 群 ──
  static Future<void> toAgentHome(BuildContext context) =>
      push(context, const AgentHomePage());

  static Future<void> toGroupChat(
    BuildContext context, {
    required String groupId,
  }) => push(context, GroupChatScreen(groupId: groupId));

  static Future<Agent?> editAgent(BuildContext context, {Agent? existing}) =>
      push(context, AgentEditPage(existing: existing));

  static Future<AgentGroup?> editGroup(BuildContext context, {AgentGroup? existing}) =>
      push(context, GroupEditPage(existing: existing));

  // ── 其他 ──
  static Future<void> toContextDocViewer(
    BuildContext context, {
    required ContextDoc doc,
  }) => push(context, ContextDocViewerPage(doc: doc));

  static Future<void> toScratchViewer(BuildContext context) =>
      push(context, const ScratchViewerPage());
}
