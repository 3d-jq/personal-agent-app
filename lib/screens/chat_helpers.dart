import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/service_locator.dart';
import '../models/chat_message.dart';
import '../services/crypto_util.dart';
import '../tools/skill_registry.dart';
import '../tools/tools.dart';

/// 安全读取环境变量，测试环境未加载 dotenv 时返回空字符串。
String _safeEnv(String key) {
  try {
    return dotenv.env[key] ?? '';
  } catch (_) {
    return '';
  }
}

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
  registry.register(WeatherTool(apiKey: CryptoUtil.decrypt(_safeEnv('GAODE_API_KEY'))));
  registry.register(LocationTool());
  registry.register(SearxngSearchTool());
  registry.register(TavilySearchTool());
  final agnesKey = CryptoUtil.decrypt(_safeEnv('AGNES_API_KEY'));
  registry.register(AgnesImageTool(apiKey: agnesKey));
  registry.register(AgnesVideoTool(apiKey: agnesKey));
  registry.register(SaveNoteTool());
  registry.register(ManageNoteTool());
  registry.register(CreateRichNoteTool());
  registry.register(AiDailyTool());
  registry.register(ContextDocTool());
  registry.register(VirtualFSTool());
  registry.register(SkillManageTool());

  // 注册内置技能
  final skillRegistry = getIt<SkillRegistry>();
  for (final skill in BuiltInSkills.all) {
    skillRegistry.register(skill);
  }

  // 工具发现层（本身也是预加载工具）
  registry.register(ToolSearchTool(registry: registry));
  registry.register(DeferExecuteTool(registry: registry));

  // 低频/场景化工具（按需发现）
  registry.registerDiscoverable(CalendarTool());
}

/// 工具名称 → 中文标签，支持通过 arguments 显示具体操作。
/// [detailed] 为 true 时显示更具体的信息（如文档名），用于时间线。
String toolLabel(String name, {Map<String, dynamic>? arguments, bool detailed = false}) {
  switch (name) {
    case 'context_doc':
      final action = arguments?['action'] as String?;
      final doc = arguments?['doc'] as String?;
      final verb = switch (action) {
        'read' => '读',
        'update' => '写',
        _ => '',
      };
      if (detailed && doc != null) {
        return '上下文文档 · $verb ${_docLabel(doc)}';
      }
      return verb.isNotEmpty ? '上下文文档 · $verb' : '上下文文档';
    case 'weather':
      return '查询天气';
    case 'location':
      return '获取位置';
    case 'searxng_search':
      return 'SearXNG搜索';
    case 'tavily_search':
      return 'Tavily搜索';
    case 'web_fetch':
      return '获取网页';
    case 'reminder':
      return '设置提醒';
    case 'generate_image':
      return '生成图片';
    case 'generate_video':
      return '生成视频';
    case 'save_note':
      return '保存笔记';
    case 'manage_notes':
      final a = arguments?['action'] as String?;
      return switch (a) { 'list' => '查看笔记', 'update' => '更新笔记', 'delete' => '删除笔记', _ => '管理笔记' };
    case 'create_rich_note':
      return '图文笔记';
    case 'calendar':
      final a = arguments?['action'] as String?;
      return switch (a) { 'query' => '查看日历', 'add' => '添加日历', 'delete' => '删除日历', _ => '日历' };
    case 'ai_daily':
      return 'AI日报';
    case 'virtual_fs':
      final a = arguments?['action'] as String?;
      return switch (a) { 'ls' => '列出目录', 'read' => '读取文件', 'write' => '写入文件', 'mkdir' => '创建目录', 'rm' => '删除', 'walk' => '遍历目录', _ => '文件系统' };
    case 'skill_manage':
      final a = arguments?['action'] as String?;
      return switch (a) { 'list' => '查看技能', 'activate' => '激活技能', 'deactivate' => '停用技能', 'match' => '匹配技能', _ => '技能管理' };
    case 'task_plan':
      final action = arguments?['action'] as String?;
      final verb = switch (action) {
        'create' => '创建',
        'update' => '更新',
        'advance' => '推进',
        'status' => '查看',
        'verify' => '校验',
        'clear' => '清除',
        _ => '',
      };
      return verb.isNotEmpty ? '任务计划 · $verb' : '任务计划';
    case 'tool_search':
      return '发现工具';
    case 'defer_execute_tool':
      return '调用延迟工具';
    case 'get_current_time':
      return '获取时间';
    case 'ask_user':
      return '询问用户';
    default:
      return name;
  }
}

String _docLabel(String? doc) => switch (doc) {
  'soul' => 'SOUL',
  'user' => 'USER',
  'agent' => 'AGENT',
  'memory' => 'MEMORY',
  'knowledge' => '知识库',
  _ => doc ?? '',
};

/// 根据文件扩展名推断 MIME 类型
String _guessMimeType(String path) {
  final ext = path.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'svg' => 'image/svg+xml',
    'pdf' => 'application/pdf',
    'json' => 'application/json',
    'csv' => 'text/csv',
    'xml' => 'application/xml',
    'yaml' || 'yml' => 'text/yaml',
    'txt' || 'md' || 'log' || 'ini' || 'cfg' || 'conf' => 'text/plain',
    'py' ||
    'js' ||
    'ts' ||
    'dart' ||
    'java' ||
    'c' ||
    'cpp' ||
    'h' ||
    'cs' ||
    'go' ||
    'rs' ||
    'rb' ||
    'php' ||
    'swift' ||
    'kt' ||
    'scala' ||
    'r' ||
    'm' ||
    'mm' ||
    'swift' => 'text/x-source',
    'html' || 'htm' => 'text/html',
    'css' => 'text/css',
    'sql' => 'application/sql',
    'sh' || 'bat' || 'cmd' || 'ps1' => 'text/x-shell',
    _ => 'application/octet-stream',
  };
}

/// 判断是否为文本类文件（可以直接读取内容发给 AI）
bool _isTextFile(String path) {
  final mime = _guessMimeType(path);
  return mime.startsWith('text/') ||
      mime == 'application/json' ||
      mime == 'application/xml' ||
      mime == 'application/sql' ||
      mime == 'application/javascript';
}

/// 构建 AI 消息历史（含系统提示词）
List<Map<String, dynamic>> buildMessageHistory({
  required String systemPrompt,
  required List<ChatMessage> messages,
  String? attachmentBase64,
  String? attachmentName,
  String? attachmentPath,
  String? pendingType,
  String? text,
  int? pendingFileSize,
  int? maxMessages, // 滑动窗口，保留最近 N 条
}) {
  final history = <Map<String, dynamic>>[
    {'role': 'system', 'content': systemPrompt},
  ];

  // 滑动窗口截断
  var msgs = messages;
  if (maxMessages != null && messages.length > maxMessages) {
    msgs = messages.sublist(messages.length - maxMessages);
  }

  for (var i = 0; i < msgs.length; i++) {
    final m = msgs[i];
    if (m.isStreaming) continue;

    // 如果 assistant 消息有工具交互记录，重建完整的工具调用链
    if (!m.isUser &&
        m.toolInteractions != null &&
        m.toolInteractions!.isNotEmpty) {
      for (final interaction in m.toolInteractions!) {
        final toolCalls = interaction['toolCalls'] as List?;
        final toolResults = interaction['toolResults'] as List?;
        // assistant 消息（带 tool_calls）
        history.add({
          'role': 'assistant',
          'content': '',
          if (toolCalls != null) 'tool_calls': toolCalls,
        });
        // tool 结果消息
        if (toolResults != null) {
          for (final tr in toolResults) {
            history.add({
              'role': 'tool',
              'tool_call_id': tr['id'],
              'content': tr['content'] ?? '',
            });
          }
        }
      }
      // 最终文本回复
      if (m.text.isNotEmpty) {
        history.add({'role': 'assistant', 'content': m.text});
      }
      continue;
    }

    final msg = <String, dynamic>{
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.text,
    };
    if (i == msgs.length - 2 && attachmentBase64 != null) {
      final userText = (text?.isEmpty ?? true) ? '' : text!;
      if (pendingType == 'image') {
        final mimeType = attachmentName != null
            ? _guessMimeType(attachmentName)
            : 'image/png';
        msg['content'] = [
          {
            'type': 'text',
            'text': userText.isEmpty ? '请基于这张图片帮我生成图片或视频' : userText,
          },
          {
            'type': 'image_url',
            'image_url': {'url': 'data:$mimeType;base64,$attachmentBase64'},
          },
        ];
      } else if (attachmentName != null &&
          _isTextFile(attachmentName) &&
          attachmentPath != null) {
        try {
          final fileContent = File(attachmentPath).readAsStringSync();
          final truncated = fileContent.length > 8000
              ? '${fileContent.substring(0, 8000)}\n\n...(内容过长，已截断)'
              : fileContent;
          msg['content'] = [
            {
              'type': 'text',
              'text':
                  '${userText.isEmpty ? '请分析这个文档' : userText}\n\n文档文件名: $attachmentName\n文件大小: $pendingFileSize bytes\n\n--- 文档内容 ---\n$truncated',
            },
          ];
        } catch (_) {
          final mimeType = _guessMimeType(attachmentName);
          msg['content'] = [
            {
              'type': 'text',
              'text':
                  '${userText.isEmpty ? '请分析这个文档' : userText}\n\n文档文件名: $attachmentName\n文件大小: $pendingFileSize bytes',
            },
            {
              'type': 'image_url',
              'image_url': {'url': 'data:$mimeType;base64,$attachmentBase64'},
            },
          ];
        }
      } else {
        final mimeType = attachmentName != null
            ? _guessMimeType(attachmentName)
            : 'application/octet-stream';
        msg['content'] = [
          {
            'type': 'text',
            'text':
                '${userText.isEmpty ? '请分析这个文档' : userText}\n\n文档文件名: $attachmentName\n文件大小: $pendingFileSize bytes',
          },
          {
            'type': 'image_url',
            'image_url': {'url': 'data:$mimeType;base64,$attachmentBase64'},
          },
        ];
      }
    }
    history.add(msg);
  }

  history.removeWhere((m) {
    final role = m['role'];
    // 保留 tool_calls 和 tool 消息，即使 content 为空
    if (role == 'tool' || m.containsKey('tool_calls')) return false;
    return (m['content'] ?? '').isEmpty ||
        (m['content'] is List && (m['content'] as List).isEmpty);
  });

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
