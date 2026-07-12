import 'package:personal_agent_app/models/agent.dart';
import 'package:personal_agent_app/models/agent_group.dart';
import 'package:personal_agent_app/models/chat_message.dart';

/// 估算群聊系统提示占用的 token（用于压缩判断与面板展示）。
///
/// 群聊未像单聊那样在 sendMessage 处显式构造 systemPrompt 字符串，这里用
/// 群名 / 描述 / 成员角色拼一份近似文本做估算，避免压缩判断漏算系统提示开销
/// （systemPrompt 通常有 2k~4k token）。
String estimateGroupSystemPrompt(AgentGroup? group, List<Agent> members) {
  final buf = StringBuffer();
  buf.writeln(group?.name ?? '');
  buf.writeln(group?.description ?? '');
  for (final m in members) {
    buf.writeln('${m.name} (${m.role})');
  }
  return buf.toString();
}

/// 群聊上下文窗口占用的估算与缓存。
///
/// 把 [GroupChatController] 里「估算 token + 轻量缓存」的状态与逻辑收拢此处，
/// 控制器只负责喂入消息列表、系统提示 token 与消息估算函数，避免在主类里堆字段。
class GroupContextUsage {
  List<ChatMessage>? _msgRef;
  int _msgLen = -1;
  int _lastLen = -1;
  int? _tokenCache;
  bool? _lastStreaming;

  /// 当前对话估算占用的 token 数（消息估算 + 系统提示估算，均为字符启发式，非真实分词）。
  /// 带轻量缓存：当消息**列表引用**变更（切会话/压缩）、**条数**变化（新增一轮问答）、
  /// **最后一条内容长度**变化（流式增长）或**最后一条流式状态翻转**（流式收尾）时重算，
  /// 其余无关刷新复用缓存。
  int compute({
    required List<ChatMessage> messages,
    required int systemPromptTokens,
    required int Function(List<ChatMessage>) estimateMessages,
  }) {
    final last = messages.isEmpty ? null : messages.last;
    final lastLen = last?.text.length ?? 0;
    final lastStreaming = last?.isStreaming ?? false;
    if (_msgRef != messages ||
        _msgLen != messages.length ||
        _lastLen != lastLen ||
        _lastStreaming != lastStreaming) {
      _msgRef = messages;
      _msgLen = messages.length;
      _lastLen = lastLen;
      _lastStreaming = lastStreaming;
      _tokenCache = estimateMessages(messages);
    }
    return (_tokenCache ?? 0) + systemPromptTokens;
  }

  /// 占用率（0~1+），估算值。
  double ratio(int tokens, int windowSize) =>
      windowSize > 0 ? tokens / windowSize : 0.0;
}
