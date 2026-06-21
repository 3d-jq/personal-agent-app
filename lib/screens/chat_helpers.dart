import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/chat_message.dart';
import '../services/crypto_util.dart';
import '../tools/tools.dart';

/// 注册所有内置工具到 ToolRegistry
///
/// - 高频/基础工具：直接进入默认 function definitions，对话前预加载。
/// - 低频/场景化工具：注册为 discoverable，不占用默认上下文；
///   需要时由模型先调用 tool_search 查找，再用 defer_execute_tool 执行。
void registerAllTools(ToolRegistry registry) {
  // 高频基础工具（预加载）
  registry.register(TaskPlanTool());
  registry.register(ReminderTool());
  registry.register(WebFetchTool());
  registry.register(WeatherTool()..apiKey = CryptoUtil.decrypt(dotenv.env['GAODE_API_KEY'] ?? ''));
  registry.register(LocationTool());
  registry.register(SearxngSearchTool());
  registry.register(TavilySearchTool());
  final agnesKey = CryptoUtil.decrypt(dotenv.env['AGNES_API_KEY'] ?? '');
  registry.register(AgnesImageTool()..apiKey = agnesKey);
  registry.register(AgnesVideoTool()..apiKey = agnesKey);
  registry.register(SaveNoteTool());
  registry.register(ManageNoteTool());
  registry.register(CreateRichNoteTool());
  registry.register(AiDailyTool());
  registry.register(ContextDocTool());

  // 工具发现层（本身也是预加载工具）
  registry.register(ToolSearchTool(registry: registry));
  registry.register(DeferExecuteTool(registry: registry));

  // 低频/场景化工具（按需发现）
  registry.registerDiscoverable(CalendarTool());
}

/// 工具名称 → 中文标签
String toolLabel(String name) {
  switch (name) {
    case 'weather': return '查询天气';
    case 'location': return '获取位置';
    case 'searxng_search': return 'SearXNG搜索';
    case 'tavily_search': return 'Tavily搜索';
    case 'web_fetch': return '获取网页';
    case 'reminder': return '设置提醒';
    case 'generate_image': return '生成图片';
    case 'generate_video': return '生成视频';
    case 'save_note': return '保存笔记';
    case 'manage_notes': return '管理笔记';
    case 'create_rich_note': return '图文笔记';
    case 'calendar': return '日历';
    case 'ai_daily': return 'AI日报';
    case 'context_doc': return '上下文文档';
    case 'task_plan': return '任务计划';
    case 'tool_search': return '发现工具';
    case 'defer_execute_tool': return '调用延迟工具';
    case 'get_current_time': return '获取时间';
    case 'ask_user': return '询问用户';
    default: return name;
  }
}

/// 构建 AI 消息历史（含系统提示词）
List<Map<String, dynamic>> buildMessageHistory({
  required String systemPrompt,
  required List<ChatMessage> messages,
  String? attachmentBase64,
  String? attachmentName,
  String? pendingType,
  String? text,
  int? pendingFileSize,
  int? maxMessages, // 滑动窗口，保留最近 N 条
}) {
  final history = <Map<String, dynamic>>[
    {'role': 'system', 'content': systemPrompt}
  ];

  // 滑动窗口截断
  var msgs = messages;
  if (maxMessages != null && messages.length > maxMessages) {
    msgs = messages.sublist(messages.length - maxMessages);
  }

  for (var i = 0; i < msgs.length; i++) {
    final m = msgs[i];
    if (m.isStreaming) continue;
    final msg = <String, dynamic>{
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.text,
    };
    if (i == msgs.length - 2 && attachmentBase64 != null) {
      if (pendingType == 'image') {
        msg['content'] = [
          {'type': 'text', 'text': (text?.isEmpty ?? true) ? '请基于这张图片帮我生成图片或视频' : text},
          {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,$attachmentBase64'}},
        ];
      } else {
        msg['content'] = [
          {'type': 'text', 'text': '${(text?.isEmpty ?? true) ? '请分析这个文档' : text}\n\n文档文件名: $attachmentName\n文件大小: $pendingFileSize bytes'},
        ];
      }
    }
    history.add(msg);
  }

  history.removeWhere((m) =>
      (m['content'] ?? '').isEmpty ||
      (m['content'] is List && (m['content'] as List).isEmpty));

  return history;
}

/// 标记所有 running 步骤为 done
void finishRunningSteps(List<TimelineStep> steps) {
  for (var i = 0; i < steps.length; i++) {
    if (steps[i].status == TimelineStepStatus.running) {
      steps[i].status = TimelineStepStatus.done;
    }
  }
}
