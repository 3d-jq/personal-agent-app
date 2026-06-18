import '../services/memory_storage.dart';

/// 统一构建 System Prompt，支持 XML 结构化 + 记忆按需筛选
class PromptBuilder {
  PromptBuilder._();

  /// 构建主聊天 System Prompt
  static String buildMainPrompt({
    required String userName,
    required String stylePrompt,
    required String customPrompt,
    required String userMessage, // 当前用户消息，用于记忆筛选
  }) {
    final buf = StringBuffer();

    // ═══ 核心人设 + 规则（固定前缀，利于缓存） ═══
    buf.writeln('<role>');
    buf.writeln('你是 DWeis，一个全能 AI 助手。你可以调用工具帮助用户完成任务。');
    buf.writeln('用户昵称：$userName');
    buf.writeln('</role>');
    buf.writeln();

    // ═══ 工具调用铁律（精简版） ═══
    buf.writeln('<rules>');
    buf.writeln('1. 需要实时信息（时间/天气/搜索）或执行操作（保存/提醒/日历）时，必须调用对应工具，不得凭训练数据猜测。');
    buf.writeln('2. 声称"已完成"前，必须先调用工具并看到成功返回。');
    buf.writeln('3. 工具失败时，根据错误信息调整参数重试一次。');
    buf.writeln('4. 查看或修改已有笔记/记忆时，先调 list 获取 id，再操作。');
    buf.writeln('</rules>');
    buf.writeln();

    // ═══ 回复风格 ═══
    if (stylePrompt.isNotEmpty) {
      buf.writeln('<style>$stylePrompt</style>');
      buf.writeln();
    }

    // ═══ 自定义指令 ═══
    if (customPrompt.isNotEmpty) {
      buf.writeln('<instructions>$customPrompt</instructions>');
      buf.writeln();
    }

    // ═══ 用户偏好（全量，通常不多） ═══
    final mem = MemoryStorage();
    final prefs = mem.cachedPreferences;
    if (prefs.isNotEmpty) {
      buf.writeln('<preferences>');
      for (final p in prefs) {
        buf.writeln('- ${p.content}');
      }
      buf.writeln('</preferences>');
      buf.writeln();
    }

    // ═══ 相关记忆（按关键词筛选，最多 5 条） ═══
    final relevantFacts = mem.relevantFacts(userMessage);
    if (relevantFacts.isNotEmpty) {
      buf.writeln('<memory>');
      for (final f in relevantFacts) {
        buf.writeln('- ${f.content}');
      }
      buf.writeln('</memory>');
    }

    return buf.toString();
  }
}
