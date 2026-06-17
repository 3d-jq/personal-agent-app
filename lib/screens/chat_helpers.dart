import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/chat_message.dart';
import '../tools/tools.dart';

/// 注册所有内置工具到 ToolRegistry
void registerAllTools(ToolRegistry registry) {
  registry.register(FileTool());
  registry.register(ClipboardTool());
  registry.register(ReminderTool());
  registry.register(WebFetchTool());
  registry.register(WeatherTool());
  registry.register(WebSearchTool());
  final agnesKey = dotenv.env['AGNES_API_KEY'] ?? '';
  registry.register(AgnesImageTool()..apiKey = agnesKey);
  registry.register(AgnesVideoTool()..apiKey = agnesKey);
  registry.register(SaveMemoryTool());
  registry.register(ManageMemoryTool());
  registry.register(SaveNoteTool());
  registry.register(ManageNoteTool());
  registry.register(TimeTool());
  registry.register(AiDailyTool());
  registry.register(CalendarTool());
}

/// 工具名称 → 中文标签
String toolLabel(String name) {
  switch (name) {
    case 'weather': return '查询天气';
    case 'web_search': return '搜索网页';
    case 'web_fetch': return '获取网页';
    case 'reminder': return '设置提醒';
    case 'file_manager': return '文件管理';
    case 'clipboard': return '剪贴板';
    case 'generate_image': return '生成图片';
    case 'generate_video': return '生成视频';
    case 'save_memory': return '记忆';
    case 'manage_memory': return '管理记忆';
    case 'save_note': return '保存笔记';
    case 'manage_notes': return '管理笔记';
    case 'get_current_time': return '获取时间';
    case 'calendar': return '日历';
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
}) {
  final history = <Map<String, dynamic>>[
    {'role': 'system', 'content': systemPrompt}
  ];

  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    if (m.isStreaming) continue;
    final msg = <String, dynamic>{
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.text,
    };
    if (i == messages.length - 2 && attachmentBase64 != null) {
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

/// 解析工具调用状态行，更新 steps 列表
void parseToolStatusLine({
  required String line,
  required List<TimelineStep> steps,
  required void Function(String name) onToolStart,
  required void Function(String name) onToolDone,
  required void Function(String name) onToolError,
}) {
  if (line.startsWith('🔧 调用工具:')) {
    final name = line.replaceFirst('🔧 调用工具:', '').trim();
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].status == TimelineStepStatus.running) {
        steps[i].status = TimelineStepStatus.done;
      }
    }
    steps.add(TimelineStep(label: toolLabel(name), type: TimelineStepType.tool, status: TimelineStepStatus.running));
    onToolStart(name);
  } else if (line.startsWith('✅') && line.contains('完成')) {
    final name = line.replaceFirst('✅', '').replaceFirst('完成', '').trim();
    final idx = steps.lastIndexWhere((s) =>
        s.type == TimelineStepType.tool &&
        s.label == toolLabel(name) &&
        s.status == TimelineStepStatus.running);
    if (idx >= 0) steps[idx].status = TimelineStepStatus.done;
    steps.add(TimelineStep(label: '思考中', type: TimelineStepType.thinking, status: TimelineStepStatus.running));
    onToolDone(name);
  } else if (line.startsWith('❌') && line.contains('失败')) {
    final name = line.replaceFirst('❌', '').replaceFirst('失败', '').trim();
    final idx = steps.lastIndexWhere((s) =>
        s.type == TimelineStepType.tool &&
        s.label == toolLabel(name) &&
        s.status == TimelineStepStatus.running);
    if (idx >= 0) steps[idx].status = TimelineStepStatus.error;
    onToolError(name);
  }
}

/// 标记所有 running 步骤为 done
void finishRunningSteps(List<TimelineStep> steps) {
  for (var i = 0; i < steps.length; i++) {
    if (steps[i].status == TimelineStepStatus.running) {
      steps[i].status = TimelineStepStatus.done;
    }
  }
}
