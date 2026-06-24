/// 通用工具结果截断器。
///
/// 作用：防止任意工具的返回内容过长，撑爆 LLM 上下文。
/// 按字符数估算（中文/英文混合约 4 字符 ≈ 1 token），在段落边界处截断，
/// 并附加提示说明。
class ToolResultTruncator {
  /// 默认最大字符数（约 1500 token）
  static const int defaultMaxChars = 6000;

  /// 截断后保留的尾部字符数，用于提示上下文
  static const int _tailChars = 200;

  final int maxChars;

  const ToolResultTruncator({this.maxChars = defaultMaxChars});

  /// 如果 [content] 超过阈值，在段落边界截断并附加提示；否则原样返回。
  String truncate(String content) {
    if (content.length <= maxChars) return content;

    // 优先在双换行（段落）处截断，保留语义完整性
    var cut = content.substring(0, maxChars - _tailChars);
    final lastBreak = cut.lastIndexOf('\n\n');
    if (lastBreak > cut.length * 0.7) {
      cut = content.substring(0, lastBreak);
    }

    final remaining = content.length - cut.length;
    return '$cut\n\n'
        '---\n'
        '[工具返回内容过长，已截断；剩余约 $remaining 字符未展示。'
        '如需分析剩余部分，请让我继续读取。]';
  }
}
