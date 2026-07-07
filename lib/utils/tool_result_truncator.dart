/// 通用工具结果截断器。
///
/// 参考 opencode 实现：
/// - 工具输出截断到 2000 字符（约 500 token）
/// - 防止工具结果撑爆上下文
class ToolResultTruncator {
  /// 最大字符数（2000 字符 ≈ 500 token）
  static const int maxChars = 2000;

  const ToolResultTruncator();

  /// 如果 [content] 超过阈值，截断并附加提示；否则原样返回。
  String truncate(String content) {
    if (content.length <= maxChars) return content;
    return '${content.substring(0, maxChars)}\n[truncated]';
  }
}
