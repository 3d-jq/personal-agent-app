/// 统一工具执行护栏常量。
///
/// 借鉴 Operit `ToolExecutionLimits`：把工具结果长度、调用频率、并发与超时
/// 上限集中管理，避免散落在 [ToolRegistry] 各处。所有常量按本项目实际值设定
/// （结果截断上限对齐 [ToolResultTruncator]）。
class ToolExecutionLimits {
  const ToolExecutionLimits._();

  /// 单个工具结果最大字符数（20000 ≈ 5000 token），超长由 [ToolResultTruncator] 截断。
  static const int maxToolResultChars = 20000;

  /// 单工具连续调用次数硬上限，超过则阻止执行（原 [ToolRegistry.maxConsecutiveCalls]）。
  static const int maxConsecutiveCallsPerTool = 15;

  /// 并发工具调用数参考上限（用于进度汇总/调度提示）。
  static const int maxConcurrentToolCalls = 8;

  /// 单个工具执行软超时（毫秒）。超过仅记日志告警，不强制杀，避免中断长任务
  /// （如 delegate_task 派活、web_fetch 大页）。
  static const int toolExecutionWarnMs = 30000;
}
