import 'dart:async';
import 'dart:convert';

/// Streams SSE `data:` payload lines from a byte stream, with a safety
/// buffer cap to prevent memory blow-up on malformed/malicious input.
///
/// Usage:
/// ```dart
/// await for (final dataLine in SseParser.parse(response.data.stream)) {
///   final json = jsonDecode(dataLine);
///   // handle event...
/// }
/// ```
class SseParser {
  /// Maximum buffer size before throwing an error (default 1 MB).
  static const defaultMaxBuffer = 1 * 1024 * 1024;

  /// Parses an SSE byte stream and yields each `data:` payload line.
  ///
  /// Handles `\r\n` / `\r` line endings via `trimRight()` after split.
  /// Skips empty payloads and `[DONE]` markers transparently.
  static Stream<String> parse(
    Stream<List<int>> byteStream, {
    int maxBuffer = defaultMaxBuffer,
  }) async* {
    final stream = byteStream
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true));
    var buffer = '';

    await for (final chunk in stream) {
      buffer += chunk;
      if (buffer.length > maxBuffer) {
        throw StateError(
            'SSE buffer exceeded ${maxBuffer ~/ 1024} KB limit');
      }

      final lines = buffer.split('\n');
      buffer = lines.removeLast();
      for (var line in lines) {
        line = line.trimRight(); // normalize \r\n
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data.isNotEmpty && data != '[DONE]') {
          yield data;
        }
      }
    }
  }
}
