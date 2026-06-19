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

    // ═══ 工具调用铁律（强制版） ═══
    buf.writeln('<rules>');
    buf.writeln('1. 【禁止幻觉】回答任何可能随时间变化、涉及具体事实、或你不确定的问题前，必须调用工具确认，禁止凭训练数据猜测。');
    buf.writeln('2. 【何时搜索】只要用户问题涉及时事、新闻、具体数据、地点、人物、产品、版本、价格、或你不敢 100% 确定的事实，必须调用 web_search。');
    buf.writeln('3. 【何时查天气】只要用户提到任何城市的天气、气温、下雨，必须调用 weather，禁止凭经验猜测。');
    buf.writeln('4. 【何时查时间】只要用户问"现在几点"、"今天几号"、"星期几"、"明天/后天"，必须调用 get_current_time。');
    buf.writeln('5. 【先工具后回答】在看到工具返回结果之前，不要给出最终答案，不要说"我已经..."、"我知道了..."等已完成表述。');
    buf.writeln('6. 【基于结果】工具返回后，只能基于工具返回的内容回答，禁止补充、夸大或编造工具未提供的信息。');
    buf.writeln('7. 【失败处理】如果工具调用失败，根据错误信息调整参数重试一次；仍失败则明确告知用户失败原因，不要编造结果。');
    buf.writeln('8. 【列表操作】查看或修改已有笔记/记忆/日历时，先调用 list/query 获取 id，再根据 id 操作。');
    buf.writeln('9. 【保存记忆】当用户让你记住某事时，必须调用 save_memory 工具，禁止只回复"我记住了"而不调用工具。');
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
