/// AI 响应流的事件类型。
///
/// 设计目的：把「AI 正文」和「工具状态」从源头分离，正文 [TextChunkEvent] 永远纯净，
/// 不再依赖字符串标记 + 正则过滤。所有工具相关状态走独立事件，消费方按事件类型分发。
///
/// 用法：`AIService.sendMessageStream` 返回 `Stream<ChatStreamEvent>`，
/// 消费方用 switch 表达式 / 模式匹配处理各事件。
sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

/// AI 正文的增量文本。消费方应累积到消息文本里。
class TextChunkEvent extends ChatStreamEvent {
  final String text;
  const TextChunkEvent(this.text);
}

/// 大模型内部推理内容（如 DeepSeek-R1 的 reasoning_content）。
/// 不显示在正文中，仅作为思考步的 detail 展示在时间线面板里。
class ThinkingChunkEvent extends ChatStreamEvent {
  final String text;
  const ThinkingChunkEvent(this.text);
}

/// 工具调用开始。
class ToolStartEvent extends ChatStreamEvent {
  final String name;
  /// 本轮并发执行的工具总数（>1 时表示并行执行）。
  final int concurrentCount;
  const ToolStartEvent(this.name, {this.concurrentCount = 1});
}

/// 工具调用成功完成。
class ToolDoneEvent extends ChatStreamEvent {
  final String name;
  const ToolDoneEvent(this.name);
}

/// 工具调用失败。
class ToolErrorEvent extends ChatStreamEvent {
  final String name;
  final String message;
  const ToolErrorEvent(this.name, this.message);
}

/// 图片/视频生成结果（媒体 URL，需追加到正文靠 markdown 渲染）。
class ToolMediaEvent extends ChatStreamEvent {
  final String url;
  const ToolMediaEvent(this.url);
}

/// 任务计划状态更新（需渲染为 checklist 卡片）。
class TaskPlanEvent extends ChatStreamEvent {
  final String title;
  final List<TaskPlanItem> tasks;
  final bool verified;
  const TaskPlanEvent({required this.title, required this.tasks, this.verified = false});
}

/// 任务计划中的单个任务项
class TaskPlanItem {
  final String id;
  final String title;
  final bool done;
  final bool inProgress;

  const TaskPlanItem({
    required this.id,
    required this.title,
    this.done = false,
    this.inProgress = false,
  });
}

/// 流式过程中的错误（网络异常、API 错误等）。
class ErrorEvent extends ChatStreamEvent {
  final String message;
  const ErrorEvent(this.message);
}

/// 一轮工具调用的完整交互记录（用于持久化到消息历史）。
/// 包含 assistant 的 tool_calls 和对应的 tool results。
class ToolInteractionEvent extends ChatStreamEvent {
  /// OpenAI 格式的 tool_calls 列表
  final List<Map<String, dynamic>> toolCalls;
  /// 工具执行结果列表: {id, content}
  final List<Map<String, dynamic>> toolResults;
  const ToolInteractionEvent({required this.toolCalls, required this.toolResults});
}
