import '../models/chat_message.dart';
import 'log_service.dart';

/// 对话历史摘要压缩管理器。
///
/// 参考 opencode 实现：
/// - 基于 token 估算触发压缩（而非固定消息数）
/// - 保留最近 N token 的消息
/// - 工具输出截断到 2000 字符
/// - 结构化摘要模板
class HistoryManager {
  /// 上下文窗口大小（token 数）
  final int contextWindowSize;

  /// 最大输出 token 数（默认 4096）
  final int maxOutputTokens;

  /// 缓冲区大小（默认 20000 token）
  final int bufferTokens;

  /// 保留最近的 token 数（默认 8000）
  final int keepTokens;

  /// 工具输出最大字符数（约 2000 字符 ≈ 500 token）
  static const int toolOutputMaxChars = 2000;

  HistoryManager({
    this.contextWindowSize = 256000,
    this.maxOutputTokens = 4096,
    this.bufferTokens = 20000,
    this.keepTokens = 8000,
  });

  final _tokenCache = <String, int>{};

  /// 估算文本的 token 数
  ///
  /// 中文约 2 字符 ≈ 1 token，英文约 4 字符 ≈ 1 token
  int estimateTokens(String text) {
    final cached = _tokenCache[text];
    if (cached != null) return cached;

    int cn = 0, en = 0;
    for (final code in text.codeUnits) {
      if (code > 0x4E00 && code < 0x9FFF) {
        cn++;
      } else if (code < 0x80) {
        en++;
      } else {
        cn++;
      }
    }
    final result = (cn / 2 + en / 4).ceil();
    _tokenCache[text] = result;
    return result;
  }

  /// 估算消息列表的总 token 数
  int estimateMessagesTokens(List<ChatMessage> messages) {
    int total = 0;
    for (final m in messages) {
      if (m.isStreaming) continue;
      total += estimateTokens(_serializeMessage(m));
    }
    return total;
  }

  /// 序列化消息为文本（用于 token 估算和摘要输入）
  String _serializeMessage(ChatMessage m) {
    if (m.isUser) {
      return '[User]: ${m.text}';
    }
    final buf = StringBuffer();
    buf.write('[Assistant]: ${m.text}');
    if (m.toolInteractions != null && m.toolInteractions!.isNotEmpty) {
      for (final interaction in m.toolInteractions!) {
        final toolCalls = interaction['toolCalls'] as List? ?? [];
        final toolResults = interaction['toolResults'] as List? ?? [];
        for (final call in toolCalls) {
          final callMap = call as Map?;
          final name = callMap?['function']?['name'] ?? '';
          final args = callMap?['function']?['arguments'] ?? '';
          buf.write('\n[Tool call]: $name($args)');
        }
        for (final tr in toolResults) {
          final content = (tr['content'] ?? '').toString();
          buf.write('\n[Tool result]: ${_truncateToolOutput(content)}');
        }
      }
    }
    return buf.toString();
  }

  /// 截断工具输出到最大字符数
  String _truncateToolOutput(String content) {
    if (content.length <= toolOutputMaxChars) return content;
    return '${content.substring(0, toolOutputMaxChars)}\n[truncated]';
  }

  /// 检查是否需要压缩
  bool shouldCompress(List<ChatMessage> messages) {
    if (messages.length <= 2) return false;
    final tokens = estimateMessagesTokens(messages);
    final threshold = contextWindowSize - (maxOutputTokens > bufferTokens ? maxOutputTokens : bufferTokens);
    final should = tokens > threshold;
    if (should) {
      log.i('HistoryManager', 'Should compress: $tokens > $threshold (context: $contextWindowSize)');
    }
    return should;
  }

  /// 如果需要压缩，对早期消息做摘要压缩
  Future<List<ChatMessage>> compressIfNeeded(
    List<ChatMessage> messages,
    Future<String> Function(List<Map<String, dynamic>> messages) summarize,
  ) async {
    if (!shouldCompress(messages)) return messages;

    log.i('HistoryManager', 'Starting compression for ${messages.length} messages');

    // 从后往前遍历，找到保留 keepTokens 的分割点
    int totalTokens = 0;
    int splitIndex = messages.length;
    for (int i = messages.length - 1; i >= 0; i--) {
      final msgTokens = estimateTokens(_serializeMessage(messages[i]));
      if (totalTokens + msgTokens > keepTokens) {
        splitIndex = i + 1;
        break;
      }
      totalTokens += msgTokens;
      splitIndex = i;
    }

    if (splitIndex <= 0) return messages;

    final toCompress = messages.sublist(0, splitIndex);
    final recent = messages.sublist(splitIndex);

    log.i('HistoryManager', 'Compressing ${toCompress.length} messages, keeping ${recent.length}');

    final summaryInput = _buildSummaryInput(toCompress);
    final summaryText = await summarize(summaryInput);

    if (summaryText.trim().isEmpty) {
      log.w('HistoryManager', 'Summary is empty, skipping compression');
      return messages;
    }

    log.i('HistoryManager', 'Compression done: ${summaryText.length} chars summary');

    final summaryMessage = ChatMessage(
      text: '[历史摘要]\n$summaryText',
      isUser: false,
    );

    return [summaryMessage, ...recent];
  }

  /// 构建摘要输入（结构化模板）
  List<Map<String, dynamic>> _buildSummaryInput(List<ChatMessage> messages) {
    final buffer = StringBuffer();
    buffer.writeln(summaryTemplate);
    buffer.writeln();
    buffer.writeln('--- 对话记录 ---');
    buffer.writeln();

    for (final m in messages) {
      if (m.isStreaming) continue;
      buffer.writeln(_serializeMessage(m));
      buffer.writeln();
    }

    return [
      {'role': 'user', 'content': buffer.toString()},
    ];
  }
}

/// 结构化摘要模板（参考 opencode）
const summaryTemplate = '''请对以下对话进行结构化摘要，严格按照以下 Markdown 格式输出，保持章节顺序不变。

## Goal
- [单句话总结任务目标]

## Constraints & Preferences
- [用户约束、偏好、规格要求，或 "(none)"]

## Progress
### Done
- [已完成的工作，或 "(none)"]

### In Progress
- [当前进行中的工作，或 "(none)"]

### Blocked
- [阻塞项，或 "(none)"]

## Key Decisions
- [决策及原因，或 "(none)"]

## Next Steps
- [有序的下一步行动，或 "(none)"]

## Critical Context
- [重要的技术事实、错误信息、待解决的问题，或 "(none)"]

## Relevant Files
- [文件或目录路径：重要性说明，或 "(none)"]

规则：
- 保留所有章节，即使为空。
- 使用简洁的要点，不要写段落。
- 保留准确的文件路径、命令、错误字符串和标识符。
- 不要提及摘要过程或上下文已被压缩。''';
