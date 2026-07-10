/// 文本清洗：移除「孤立 UTF-16 代理字符」(lone surrogate)。
///
/// 背景：Flutter 的 `_NativeParagraphBuilder.addText` 在收到含孤立代理
/// (U+D800–U+DFFF 未成对) 的字符串时会抛
/// `Invalid argument(s): string is not well-formed UTF-16` 并红屏。
/// 这类字符可能来自：
///   - LLM 流式返回的 JSON 里出现了不配对的 `\uXXXX` 转义
///   - 多字节字符在网络分包边界被错误解码（历史脏数据）
///
/// 清洗策略：逐 code unit 扫描，保留合法的代理对 (高代理+低代理)，
/// 丢弃孤立的高/低代理。普通文本走快速路径，零分配开销。
String sanitizeUtf16(String input) {
  // 快速路径：整串不含任何代理字符 (U+D800–U+DFFF) 时直接返回原串。
  var hasSurrogate = false;
  for (var i = 0; i < input.length; i++) {
    final c = input.codeUnitAt(i);
    if (c >= 0xD800 && c <= 0xDFFF) {
      hasSurrogate = true;
      break;
    }
  }
  if (!hasSurrogate) return input;

  final buffer = StringBuffer();
  var i = 0;
  while (i < input.length) {
    final c = input.codeUnitAt(i);
    if (c >= 0xD800 && c <= 0xDBFF) {
      // 高代理：必须紧跟一个低代理才合法。
      if (i + 1 < input.length) {
        final next = input.codeUnitAt(i + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          buffer.writeCharCode(c);
          buffer.writeCharCode(next);
          i += 2;
          continue;
        }
      }
      // 孤立高代理 → 丢弃。
      i += 1;
      continue;
    } else if (c >= 0xDC00 && c <= 0xDFFF) {
      // 孤立低代理 → 丢弃。
      i += 1;
      continue;
    }
    buffer.writeCharCode(c);
    i += 1;
  }
  return buffer.toString();
}
