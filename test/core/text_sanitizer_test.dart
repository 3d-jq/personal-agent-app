import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/text_sanitizer.dart';

void main() {
  group('sanitizeUtf16', () {
    test('普通文本原样返回（快速路径）', () {
      const s = '你好，世界！Hello, 世界 🌸 emoji test.';
      expect(sanitizeUtf16(s), s);
    });

    test('空串与纯 ASCII 不变', () {
      expect(sanitizeUtf16(''), '');
      expect(sanitizeUtf16('hello world'), 'hello world');
    });

    test('合法代理对（emoji）保留', () {
      // 😀 = U+1F600 → 代理对 0xD83D 0xDE00
      const emoji = 'a\uD83D\uDE00b';
      expect(sanitizeUtf16(emoji), emoji);
    });

    test('孤立高代理被移除', () {
      const dirty = 'abc\uD83Ddef'; // 高代理无配对低代理
      expect(sanitizeUtf16(dirty), 'abcdef');
    });

    test('孤立低代理被移除', () {
      const dirty = 'abc\uDE00def'; // 低代理无配对高代理
      expect(sanitizeUtf16(dirty), 'abcdef');
    });

    test('多个孤立代理连续出现全部移除', () {
      // 注意：\uD800\uDFFF 是一对「合法」代理对（U+103FF），不能算孤立；
      // 这里特意用两个相邻高代理 \uD800\uD801（彼此都不构成合法对）与两个相邻低代理。
      const dirty = '\uD800\uD801x\uDC00\uDC01y';
      expect(sanitizeUtf16(dirty), 'xy');
    });

    test('代理对与孤立代理混合只移除孤立的', () {
      // 合法 😀 + 孤立高代理 + 合法 🌸(U+1F338 = 0xD83C 0xDF38)
      const dirty = 'A\uD83D\uDE00\uDC00B\uD83C\uDF38C';
      expect(sanitizeUtf16(dirty), 'A\uD83D\uDE00B\uD83C\uDF38C');
    });
  });
}
