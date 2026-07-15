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

abstract class BrowserBaseTool extends AgentTool {
  final BrowserChannel channel;

  BrowserBaseTool(this.channel);

  @override
  bool get readOnly => false;

  /// 执行 JS 并把 WebView 回调的 JSON 字符串结果解码为纯文本。
  ///
  /// WebView.evaluateJavascript 的回调值是「值的 JSON 表示」——字符串会被包成
  /// 带引号的 JSON 字符串（如 `"hello"`）。这里统一去掉外层引号，返回真实文本。
  Future<String> evalText(String code) async {
    final raw = await channel.evaluateJs(code);
    return _decodeJsString(raw);
  }

  /// 执行 JS 并把结果解析为 JSON（Map/List）。失败时返回 null。
  Future<dynamic> evalJson(String code) async {
    final raw = await channel.evaluateJs(code);
    final s = _decodeJsString(raw);
    try {
      return jsonDecode(s);
    } on FormatException {
      return null;
    }
  }

  /// 将原生错误/结果转为 AI 友好的纠错建议。
  /// [action] 是当前操作名（如 "点击"），[detail] 是额外上下文。
  static String friendlyError(String result, String action, [String? detail]) {
    final r = result.toLowerCase();
    if (r.contains('ref_not_found')) {
      return '$action失败：找不到目标元素。页面可能已变化，请**重新执行 browser_snapshot** 获取最新元素列表，再用新的 ref 操作。';
    }
    if (r.contains('ref_not_select')) {
      return '$action失败：该元素不是 <select> 下拉框。请确认 browser_snapshot 中该元素的 tag 为 SELECT，或用其他 ref 重试。';
    }
    if (r.contains('option_not_found')) {
      final val = detail ?? '';
      return '$action失败：未找到匹配的选项 "$val"。请检查 browser_snapshot 中该 select 的可用选项（可通过 browser_get_text 查看）。';
    }
    if (r.contains('not_loaded') || r.contains('尚未加载')) {
      return '$action失败：页面尚未加载完成。请先执行 browser_goto 打开目标页面，或等待页面加载后重试。';
    }
    if (r.contains('screenshot_failed') || r.contains('宽高') || r.contains('布局')) {
      return '$action失败：WebView 尚未就绪。请先**打开浏览器**（让 WebView 浮层展示出来），然后重试截图。';
    }
    if (r.contains('timeout') || r.contains('超时')) {
      return '$action失败：操作超时。请增大等待时长（ms 参数），或用 browser_wait 的 ref 参数等待关键元素出现后再操作。';
    }
    return '$action失败：$result';
  }
}
String _decodeJsString(String raw) {
  if (raw.isEmpty) return '';
  try {
    final d = jsonDecode(raw);
    if (d is String) return d;
    return d.toString();
  } on FormatException {
    return raw;
  }
}

/// 分页辅助：截取 [content] 的 [offset, offset+maxLen) 段；若还有剩余，
/// 末尾附「继续读取」提示，让大模型能像翻页一样拿全长内容
///（绕过全局 20000 字符工具结果截断导致大模型「看不见下文」的问题）。
String topPaginate(String content, int offset, int maxLen) {
  if (content.length <= maxLen) return content;
  final end = (offset + maxLen).clamp(0, content.length);
  final slice = content.substring(offset, end);
  final remaining = content.length - end;
  if (remaining <= 0) return slice;
  return '$slice\n\n'
      '[内容较长：本段显示第 $offset–$end 字符，还剩 $remaining 字符未展示。'
      '请用 offset=$end 再次调用本工具继续读取剩余内容。]';
}

