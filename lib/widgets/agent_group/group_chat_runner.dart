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

/// 执行一个 Agent 的流式回复，并返回最终文本。
///
/// 从 [GroupChatScreen] 的 `_runOneAgent` 抽取为独立函数：群聊主屏只负责 UI 与编排，
/// 流式解析 / 打字机 / 工具时间线等重逻辑集中在此，互不耦合。
///
/// [placeholder] 由调用方创建并加入消息列表；本函数只负责填充其 `text` 与 `steps`，
/// 并通过 [onScroll] / [onChanged] 回调触发滚动与重建。
Future<String> runGroupAgentMessage({
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
  AgentTool? dispatchTool,
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
    return errText;
  }

  final buf = StringBuffer();
  final typewriter = TypewriterBuffer(charsPerTick: 4);
  Timer? typewriterTimer;
  List<TimelineStep>? currentSteps;
  final toolInteractions = <Map<String, dynamic>>[];
  StreamSubscription<ChatStreamEvent>? sub;
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
      dispatchTool: dispatchTool,
      isGroupChat: true,
    );
    final completer = Completer<void>();
    sub = stream.listen(
      (event) {
        switch (event) {
          case ThinkingChunkEvent():
            break;
          case TextChunkEvent(:final text):
            buf.write(text);
            typewriter.append(text);
            break;
          case ToolStartEvent(:final name, :final concurrentCount, :final arguments):
            currentSteps ??= [];
            for (final s in currentSteps!) {
              if (s.type == TimelineStepType.thinking &&
                  s.status == TimelineStepStatus.running) {
                s.status = TimelineStepStatus.done;
              }
            }
            final detailLabel =
                toolLabel(name, arguments: arguments, detailed: true);
            final suffix = concurrentCount > 1 ? ' ×$concurrentCount' : '';
            currentSteps!.add(
              TimelineStep(
                label: '$detailLabel$suffix',
                type: TimelineStepType.tool,
                status: TimelineStepStatus.running,
                detail: '工具: $name',
              ),
            );
            break;
          case ToolDoneEvent(:final name):
            if (currentSteps != null) {
              final idx = currentSteps!.lastIndexWhere(
                (s) =>
                    s.type == TimelineStepType.tool &&
                    s.detail == '工具: $name' &&
                    s.status == TimelineStepStatus.running,
              );
              if (idx >= 0) {
                currentSteps![idx].status = TimelineStepStatus.done;
                currentSteps![idx].detail = '执行成功';
              }
            }
            break;
          case ToolErrorEvent(:final name, :final message):
            if (currentSteps != null) {
              final idx = currentSteps!.lastIndexWhere(
                (s) =>
                    s.type == TimelineStepType.tool &&
                    s.detail == '工具: $name' &&
                    s.status == TimelineStepStatus.running,
              );
              if (idx >= 0) {
                currentSteps![idx].status = TimelineStepStatus.error;
                currentSteps![idx].detail = message;
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
    // 超时保护：防止流挂死导致接力永久阻塞
    await completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        buf.write('\n\n[连接超时，请重试]');
        typewriter.append('\n\n[连接超时，请重试]');
        typewriter.revealAll();
        placeholder.text = stripArtifactTokens(buf.toString());
      },
    );
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
  return buf.toString();
}
