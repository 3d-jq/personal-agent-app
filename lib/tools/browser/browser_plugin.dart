import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../../platform/browser_channel.dart';
import '../../services/log_service.dart';
import '../base_tool.dart';
import '../plugin_registry.dart';
import '../tool_registry.dart';
import '../browser_goto_tool.g.dart';
import '../browser_snapshot_tool.g.dart';
import '../browser_click_tool.g.dart';
import '../browser_type_tool.g.dart';
import '../browser_select_tool.g.dart';
import '../browser_fill_form_tool.g.dart';
import '../browser_evaluate_tool.g.dart';
import '../browser_back_tool.g.dart';
import '../browser_close_tool.g.dart';
import '../browser_screenshot_tool.g.dart';
import '../browser_get_text_tool.g.dart';
import '../browser_get_readable_tool.g.dart';
import '../browser_get_page_info_tool.g.dart';
import '../browser_find_elements_tool.g.dart';
import '../browser_scroll_tool.g.dart';
import '../browser_wait_tool.g.dart';
import '../browser_search_tool.g.dart';
import '../browser_set_user_agent_tool.g.dart';
import '../browser_set_viewport_tool.g.dart';
import '../browser_get_cookies_tool.g.dart';
import '../browser_set_cookies_tool.g.dart';
import '../browser_hover_tool.g.dart';
import '../browser_get_backbone_tool.g.dart';
import '../browser_scroll_and_collect_tool.g.dart';

import 'browser_nav_tools.dart';
import 'browser_interact_tools.dart';
import 'browser_data_tools.dart';

class BrowserToolsPlugin extends AppPlugin {
  final BrowserChannel channel;

  BrowserToolsPlugin([BrowserChannel? channel])
      : channel = channel ?? BrowserChannel();

  @override
  String get id => 'browser';

  @override
  Future<void> init() async {}

  @override
  void provideTools(ToolRegistry registry) {
    if (!registry.has('browser_goto')) {
      registry.register(BrowserGotoTool(channel));
    }
    if (!registry.has('browser_snapshot')) {
      registry.register(BrowserSnapshotTool(channel));
    }
    if (!registry.has('browser_click')) {
      registry.register(BrowserClickTool(channel));
    }
    if (!registry.has('browser_type')) {
      registry.register(BrowserTypeTool(channel));
    }
    if (!registry.has('browser_select')) {
      registry.register(BrowserSelectTool(channel));
    }
    if (!registry.has('browser_fill_form')) {
      registry.register(BrowserFillFormTool(channel));
    }
    if (!registry.has('browser_evaluate')) {
      registry.register(BrowserEvaluateTool(channel));
    }
    if (!registry.has('browser_back')) {
      registry.register(BrowserBackTool(channel));
    }
    if (!registry.has('browser_close')) {
      registry.register(BrowserCloseTool(channel));
    }
    if (!registry.has('browser_screenshot')) {
      registry.register(BrowserScreenshotTool(channel));
    }
    // 内容读取 / 导航 / 控制（v1.7.0 增强）
    if (!registry.has('browser_get_text')) {
      registry.register(BrowserGetTextTool(channel));
    }
    if (!registry.has('browser_get_readable')) {
      registry.register(BrowserGetReadableTool(channel));
    }
    if (!registry.has('browser_get_page_info')) {
      registry.register(BrowserGetPageInfoTool(channel));
    }
    if (!registry.has('browser_find_elements')) {
      registry.register(BrowserFindElementsTool(channel));
    }
    if (!registry.has('browser_scroll')) {
      registry.register(BrowserScrollTool(channel));
    }
    if (!registry.has('browser_wait')) {
      registry.register(BrowserWaitTool(channel));
    }
    if (!registry.has('browser_search')) {
      registry.register(BrowserSearchTool(channel));
    }
    if (!registry.has('browser_set_user_agent')) {
      registry.register(BrowserSetUserAgentTool(channel));
    }
    if (!registry.has('browser_set_viewport')) {
      registry.register(BrowserSetViewportTool(channel));
    }
    if (!registry.has('browser_get_cookies')) {
      registry.register(BrowserGetCookiesTool(channel));
    }
    if (!registry.has('browser_set_cookies')) {
      registry.register(BrowserSetCookiesTool(channel));
    }
    if (!registry.has('browser_hover')) {
      registry.register(BrowserHoverTool(channel));
    }
    if (!registry.has('browser_get_backbone')) {
      registry.register(BrowserGetBackboneTool(channel));
    }
    if (!registry.has('browser_scroll_and_collect')) {
      registry.register(BrowserScrollAndCollectTool(channel));
    }
  }
}
