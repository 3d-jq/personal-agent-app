import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/typewriter_buffer.dart';

void main() {
  group('TypewriterBuffer', () {
    test('reveals appended text incrementally', () {
      final buffer = TypewriterBuffer(charsPerTick: 2);

      buffer.append('你好世界');
      expect(buffer.visibleText, '');
      expect(buffer.hasPending, true);

      buffer.revealNext();
      expect(buffer.visibleText, '你好');
      expect(buffer.hasPending, true);

      buffer.revealNext();
      expect(buffer.visibleText, '你好世界');
      expect(buffer.hasPending, false);
    });

    test('keeps full text while revealing partial text', () {
      final buffer = TypewriterBuffer(charsPerTick: 3);
      buffer.append('abcdef');
      buffer.revealNext();

      expect(buffer.fullText, 'abcdef');
      expect(buffer.visibleText, 'abc');
    });

    test('revealAll shows all pending text', () {
      final buffer = TypewriterBuffer(charsPerTick: 1);
      buffer.append('abcdef');

      buffer.revealAll();

      expect(buffer.visibleText, 'abcdef');
      expect(buffer.hasPending, false);
    });
  });
}
