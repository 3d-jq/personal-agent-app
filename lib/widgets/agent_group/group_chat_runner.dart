import 'dart:async';

import 'package:personal_agent_app/models/agent.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/screens/chat_helpers.dart';
import 'package:personal_agent_app/services/agent_runner.dart';
import 'package:personal_agent_app/services/chat_stream_event.dart';
import 'package:personal_agent_app/tools/base_tool.dart';
import 'package:personal_agent_app/tools/task_plan_tool.dart';
import 'package:personal_agent_app/services/typewriter_buffer.dart';
import 'package:personal_agent_app/widgets/vendor_config.dart';

/// 剥离模型偶发产出的控制标记（如 [[reply_to_current]]），
/// 这些 token 在群里没有实际语义，却会泄漏到气泡文本里。
String stripArtifactTokens(String text) {
  return text
      .replaceAll(
        RegExp(r'\[\[\s*reply_to[^\]]*\]\]', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'\[\[[^\]]*\]\]'), '');
}

/// 单个 Agent 执行的挂死保护超时：超过即自动以「[连接超时]」收尾，
/// delegate_task 场景中子 Agent 可能需多轮工具调用 + LLM 思考，90s 过短。
const _agentRunTimeout = Duration(seconds: 180);

/// 子 Agent 一次执行的结局，供调用方更新 [AgentStatus]（错误/超时/被终止可见）。
enum ChildOutcome {
  ok, // 正常完成
  error, // 执行出错（流/工具异常，气泡含 [错误:）
  timeout, // 连接或响应超时（长时间无响应）
  cancelled, // 被用户「停止」终止（abort 信号）
}

/// 执行一个 Agent 的流式回复，并返回「最终文本 + 结局」。
///
/// 从 [GroupChatScreen] 的 `_runOneAgent` 抽取为独立函数：群聊主屏只负责 UI 与编排，
/// 流式解析 / 打字机 / 工具时间线等重逻辑集中在此，互不耦合。
///
/// [placeholder] 由调用方创建并加入消息列表；本函数只负责填充其 `text` 与 `steps`，
/// 并通过 [onScroll] / [onChanged] 回调触发滚动与重建。
///
/// [abortSignal] 非空时，外部（用户停止 / 主 Agent 终止子 Agent）完成它即可立即中断
/// 本次执行（不再傻等整段流结束）。[onFinish] 在执行结束时回调结局，便于上层更新状态。
Future<(String, ChildOutcome)> runGroupAgentMessage({
  required Agent agent,
  required List<VendorConfig> vendors,
  required VendorConfig? selectedVendor,
  required String thinkingEffort,
  required List<ChatMessage> history,
  required List<String> memberNames,
  required Map<String, String> speakerNames,
  required Map<String, String> memberRoles,
  required String groupName,
  required String groupDesc,
  required ChatMessage placeholder,
  required AgentRunner runner,
  required List<StreamSubscription<ChatStreamEvent>> activeSubs,
  required void Function() onScroll,
  required void Function() onChanged,
  List<AgentTool>? dispatchTools,
  required Completer<void>? abortSignal,
  void Function(ChildOutcome)? onFinish,
}) async {
  VendorConfig? vendor;
  if (agent.vendorId.isNotEmpty) {
    vendor = vendors.where((v) => v.id == agent.vendorId).firstOrNull;
  }
  vendor ??= selectedVendor ?? (vendors.isNotEmpty ? vendors.first : null);
  if (vendor == null || vendor.apiKey.isEmpty) {
    final errText = '${agent.name} 没有可用的 AI 后端';
    placeholder.isStreaming = false;
    placeholder.text = errText;
    onChanged();
    onScroll();
    return (errText, ChildOutcome.error);
  }

  final buf = StringBuffer();
  final typewriter = TypewriterBuffer(charsPerTick: 4);
  Timer? typewriterTimer;
  List<TimelineStep>? currentSteps;
  int concurrentStarted = 0;
  final toolInteractions = <Map<String, dynamic>>[];
  StreamSubscription<ChatStreamEvent>? sub;
  final completer = Completer<void>();
  final aborted = Completer<void>();
  var timedOut = false;
  try {
    final stream = runner.run(
      agent: agent,
      vendor: vendor,
      groupMessages: history,
      memberNames: memberNames,
      speakerNames: speakerNames,
      memberRoles: memberRoles,
      groupName: groupName,
      groupDesc: groupDesc,
      thinkingEffort: thinkingEffort,
      dispatchTools: dispatchTools,
      isGroupChat: true,
    );
    sub = stream.listen(
      (event) {
        switch (event) {
          case ThinkingChunkEvent():
            break;
          case TextChunkEvent(:final text):
            buf.write(text);
            typewriter.append(text);
            break;
          case ToolStartEvent(:final name, :final id, :final concurrentCount, :final arguments):
            currentSteps ??= [];
            for (final s in currentSteps!) {
              if (s.type == TimelineStepType.thinking &&
                  s.status == TimelineStepStatus.running) {
                s.status = TimelineStepStatus.done;
              }
            }
            final detailLabel =
                toolLabel(name, arguments: arguments, detailed: true);
            // 并发批次：仅在本批次「最后一个」并发工具上标注 ×N，避免 N 行都写 ×N 造成 N×N 错觉
            final isConcurrent = concurrentCount > 1;
            concurrentStarted += 1;
            final isLastInGroup =
                isConcurrent && concurrentStarted >= concurrentCount;
            final suffix = isLastInGroup ? ' ×$concurrentCount' : '';
            currentSteps!.add(
              TimelineStep(
                label: '$detailLabel$suffix',
                type: TimelineStepType.tool,
                status: TimelineStepStatus.running,
                detail: '工具: $name',
                toolId: id,
              ),
            );
            if (isLastInGroup) concurrentStarted = 0;
            break;
          case ToolDoneEvent(:final id):
            if (currentSteps != null) {
              final idx = currentSteps!.lastIndexWhere(
                (s) =>
                    s.type == TimelineStepType.tool &&
                    s.toolId == id &&
                    s.status == TimelineStepStatus.running,
              );
              if (idx >= 0) {
                currentSteps![idx].status = TimelineStepStatus.done;
                currentSteps![idx].detail = '执行成功';
              }
              if (!currentSteps!.any(
                (s) =>
                    s.type == TimelineStepType.tool &&
                    s.status == TimelineStepStatus.running,
              )) {
                concurrentStarted = 0;
              }
            }
            break;
          case ToolErrorEvent(:final id, :final message):
            if (currentSteps != null) {
              final idx = currentSteps!.lastIndexWhere(
                (s) =>
                    s.type == TimelineStepType.tool &&
                    s.toolId == id &&
                    s.status == TimelineStepStatus.running,
              );
              if (idx >= 0) {
                currentSteps![idx].status = TimelineStepStatus.error;
                currentSteps![idx].detail = message;
              }
              if (!currentSteps!.any(
                (s) =>
                    s.type == TimelineStepType.tool &&
                    s.status == TimelineStepStatus.running,
              )) {
                concurrentStarted = 0;
              }
            }
            break;
          case ToolMediaEvent(:final url):
            buf.write('\n$url\n');
            typewriter.append('\n$url\n');
            break;
          case ToolInteractionEvent(:final toolCalls, :final toolResults):
            toolInteractions.add({
              'toolCalls': toolCalls,
              'toolResults': toolResults,
            });
            break;
          case TaskPlanEvent(:final title, :final tasks, :final verified):
            placeholder.plan = TaskPlan(
              title: title,
              verified: verified,
              tasks: tasks
                  .map(
                    (t) => TaskNode(
                      id: t.id,
                      title: t.title,
                      status: t.done
                          ? TaskStatus.done
                          : t.inProgress
                          ? TaskStatus.inProgress
                          : TaskStatus.pending,
                    ),
                  )
                  .toList(),
            );
            break;
          case ErrorEvent(:final message):
            buf.write('\n\n[错误: $message]');
            typewriter.append('\n\n[错误: $message]');
            break;
        }
        placeholder.text = typewriter.visibleText;
        placeholder.steps = currentSteps;
        // placeholder 是 ChatMessage(ChangeNotifier)，text/steps 赋值即通知，
        // 对应气泡的 ListenableBuilder 会局部重建，无需整屏 setState。
        onScroll();

        // 启动打字机定时器
        typewriterTimer ??= Timer.periodic(const Duration(milliseconds: 24), (_) {
          if (!typewriter.hasPending) {
            typewriterTimer?.cancel();
            typewriterTimer = null;
            return;
          }
          typewriter.revealNext();
          placeholder.text = typewriter.visibleText;
          onScroll();
        });
      },
      onDone: () {
        typewriterTimer?.cancel();
        typewriterTimer = null;
        typewriter.revealAll();
        placeholder.text = stripArtifactTokens(buf.toString());
        completer.complete();
      },
      onError: (e) {
        typewriterTimer?.cancel();
        typewriterTimer = null;
        buf.write('\n\n[错误: $e]');
        typewriter.append('\n\n[错误: $e]');
        typewriter.revealAll();
        placeholder.text = stripArtifactTokens(buf.toString());
        completer.complete();
      },
      cancelOnError: true,
    );
    activeSubs.add(sub);
    // 超时 + 中止保护：防止流挂死导致协调者永久阻塞。
    // abortSignal 由外部（用户停止 / 主 Agent 终止子 Agent）完成即立即中断；
    // 超过 _agentRunTimeout 仍未结束则自动以「[连接超时]」收尾。
    abortSignal?.future.then((_) => aborted.complete());
    await Future.any([
      completer.future,
      aborted.future,
      Future.delayed(_agentRunTimeout),
    ]);
    if (aborted.isCompleted && !completer.isCompleted) {
      await sub.cancel();
      buf.write('\n\n[已被终止]');
      typewriter.append('\n\n[已被终止]');
      typewriter.revealAll();
      placeholder.text = stripArtifactTokens(buf.toString());
    } else if (!completer.isCompleted) {
      timedOut = true;
      await sub.cancel();
      buf.write('\n\n[连接超时，已自动结束]');
      typewriter.append('\n\n[连接超时，已自动结束]');
      typewriter.revealAll();
      placeholder.text = stripArtifactTokens(buf.toString());
    }
  } finally {
    await sub?.cancel();
    typewriterTimer?.cancel();
    if (sub != null) activeSubs.remove(sub);
    placeholder.isStreaming = false;
    final steps = currentSteps;
    if (steps != null && steps.isNotEmpty) {
      finishRunningSteps(steps);
      if (steps.last.type == TimelineStepType.thinking) {
        steps.last.label = '任务完成';
      }
      placeholder.steps = steps;
    }
    if (toolInteractions.isNotEmpty) {
      placeholder.toolInteractions = toolInteractions;
    }
  }
  onChanged();
  onScroll();
  final outcome = aborted.isCompleted && !completer.isCompleted
      ? ChildOutcome.cancelled
      : timedOut
          ? ChildOutcome.timeout
          : buf.toString().contains('[错误:')
              ? ChildOutcome.error
              : ChildOutcome.ok;
  onFinish?.call(outcome);
  return (buf.toString(), outcome);
}
