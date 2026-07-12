import 'dart:async';

import 'package:personal_agent_app/models/agent.dart';

/// 一次 delegate_task 派发的记录，用于在协调者轮结束后把其气泡渲染成派发卡片。
class DispatchRecord {
  final String agentName;
  final String brief;
  DispatchRecord(this.agentName, this.brief);
}

/// 一个正在运行的子 Agent 的可取消句柄。
/// [abort] 由「停止」完成，使其执行流立即以「[已被终止]」收尾，
/// 并把结果回灌协调者，由协调者决定继续、重试或汇总。
class ChildRun {
  final Agent agent;
  final Completer<void> abort;
  ChildRun({required this.agent, required this.abort});
}

/// 极简串行锁：保证回调一次只跑一个，后续排队依次执行。
///
/// 群聊协调者可能在一次回复里并行发起多个 [DelegateTaskTool] 调用
/// （executeAllTools 用 Future.wait 并发执行），用本锁把子 Agent 的派活
/// 串行化，避免并发修改消息列表与状态、保证可预测的执行顺序。
class SerialLock {
  Future<void> _chain = Future.value();

  Future<T> run<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _chain = _chain.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
