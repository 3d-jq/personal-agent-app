import 'base_tool.dart';

/// 工具调用拦截决策。
sealed class ToolHookDecision {
  const ToolHookDecision();
}

class ToolHookAllow extends ToolHookDecision {
  const ToolHookAllow();
}

class ToolHookBlock extends ToolHookDecision {
  final String reason;
  const ToolHookBlock(this.reason);
}

/// 工具调用生命周期钩子。
///
/// 借鉴 Operit `AIToolHook`：在工具执行的各个阶段插入观察/拦截逻辑，
/// 用于审计、权限校验、限流、埋点等。在 [onToolCallIntercept] 返回
/// [ToolHookBlock] 可阻止该工具执行。
abstract class ToolHook {
  /// 收到工具调用请求时。
  void onToolCallRequested(AgentTool tool) {}

  /// 在执行前（频率/权限检查之前）调用。返回 [ToolHookBlock] 阻止执行。
  ToolHookDecision onToolCallIntercept(AgentTool tool) => const ToolHookAllow();

  /// 权限/频率检查完成后（如适用）。
  void onToolPermissionChecked(AgentTool tool, bool granted, [String? reason]) {}

  /// 实际执行即将开始。
  void onToolExecutionStarted(AgentTool tool) {}

  /// 产生执行结果。
  void onToolExecutionResult(AgentTool tool, ToolResult result) {}

  /// 执行抛出异常。
  void onToolExecutionError(AgentTool tool, Object error) {}

  /// 工具请求生命周期结束。
  void onToolExecutionFinished(AgentTool tool) {}
}

/// 串行执行一组 [ToolHook]，并把首个 [ToolHookBlock] 决策向上传递。
class ToolHookChain {
  final List<ToolHook> _hooks;
  ToolHookChain(this._hooks);

  void onToolCallRequested(AgentTool tool) {
    for (final h in _hooks) {
      h.onToolCallRequested(tool);
    }
  }

  ToolHookDecision onToolCallIntercept(AgentTool tool) {
    for (final h in _hooks) {
      final d = h.onToolCallIntercept(tool);
      if (d is ToolHookBlock) return d;
    }
    return const ToolHookAllow();
  }

  void onToolPermissionChecked(AgentTool tool, bool granted, [String? reason]) {
    for (final h in _hooks) {
      h.onToolPermissionChecked(tool, granted, reason);
    }
  }

  void onToolExecutionStarted(AgentTool tool) {
    for (final h in _hooks) {
      h.onToolExecutionStarted(tool);
    }
  }

  void onToolExecutionResult(AgentTool tool, ToolResult result) {
    for (final h in _hooks) {
      h.onToolExecutionResult(tool, result);
    }
  }

  void onToolExecutionError(AgentTool tool, Object error) {
    for (final h in _hooks) {
      h.onToolExecutionError(tool, error);
    }
  }

  void onToolExecutionFinished(AgentTool tool) {
    for (final h in _hooks) {
      h.onToolExecutionFinished(tool);
    }
  }
}
