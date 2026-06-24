import '../models/chat_message.dart';

/// 对话历史摘要压缩管理器。
///
/// 当消息数超过阈值时，把较早的对话批量生成一段摘要，替换原消息，
/// 从而避免滑动窗口直接丢弃老消息导致的信息丢失。
/// 最近几轮对话保持完整，确保当前上下文的连贯性。
class HistoryManager {
  /// 触发压缩的消息数阈值
  final int compressThreshold;

  /// 保留最近的完整消息数（必须包含当前用户消息和最近回复）
  final int keepRecentMessages;

  const HistoryManager({
    this.compressThreshold = 30,
    this.keepRecentMessages = 8,
  });

  /// 如果消息数未超过阈值，直接返回原列表；否则压缩早期消息。
  ///
  /// [summarize] 是一个异步函数，接收待摘要的消息历史（OpenAI 格式），
  /// 返回摘要文本。
  Future<List<ChatMessage>> compressIfNeeded(
    List<ChatMessage> messages,
    Future<String> Function(List<Map<String, dynamic>> messages) summarize,
  ) async {
    if (messages.length <= compressThreshold) return messages;

    final keepStart = messages.length - keepRecentMessages;
    if (keepStart <= 0) return messages;

    final toCompress = messages.sublist(0, keepStart);
    final recent = messages.sublist(keepStart);

    final summaryInput = _buildSummaryInput(toCompress);
    final summaryText = await summarize(summaryInput);

    if (summaryText.trim().isEmpty) return messages;

    final summaryMessage = ChatMessage(
      text: '[历史摘要] $summaryText',
      isUser: false,
    );

    return [summaryMessage, ...recent];
  }

  List<Map<String, dynamic>> _buildSummaryInput(List<ChatMessage> messages) {
    final buffer = StringBuffer();
    buffer.writeln('请对以下对话进行简洁摘要，保留关键事实、用户意图和已完成的操作结果。'
        '摘要用于替代原始对话进入后续上下文，所以请尽量完整。');
    buffer.writeln();
    buffer.writeln('--- 对话记录 ---');

    for (final m in messages) {
      if (m.isStreaming) continue;
      final role = m.isUser ? '用户' : 'AI';
      var text = m.text;
      if (m.toolInteractions != null && m.toolInteractions!.isNotEmpty) {
        final toolNames = m.toolInteractions!
            .expand((i) => (i['toolCalls'] as List? ?? []))
            .map((c) => (c as Map?)?['function']?['name'] ?? '')
            .where((n) => n.isNotEmpty)
            .toSet();
        if (toolNames.isNotEmpty) {
          text = '$text\n[调用工具: ${toolNames.join(', ')}]';
        }
      }
      if (text.trim().isEmpty) continue;
      buffer.writeln('$role: $text');
    }

    return [
      {'role': 'user', 'content': buffer.toString()},
    ];
  }
}
