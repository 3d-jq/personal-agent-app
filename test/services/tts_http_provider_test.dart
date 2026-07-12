import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/tts_http_provider.dart';

void main() {
  group('HttpTtsProvider 请求构造（纯逻辑）', () {
    test('endpoint 拼接并去尾斜杠', () {
      final p = HttpTtsProvider(
        baseUrl: 'https://api.openai.com/v1/',
        apiKey: 'k',
        model: 'm',
      );
      expect(p.endpoint, 'https://api.openai.com/v1/audio/speech');
    });

    test('buildBody 含 model/voice/input/format', () {
      final p = HttpTtsProvider(
        baseUrl: 'x',
        apiKey: 'k',
        model: 'm',
        voiceId: 'v',
        rate: 0.5,
      );
      final b = p.buildBody('你好');
      expect(b['model'], 'm');
      expect(b['voice'], 'v');
      expect(b['input'], '你好');
      expect(b['response_format'], 'mp3');
      expect(b['speed'], 0.5);
    });

    test('speed 越界被 clamp 到 OpenAI 合法范围 0.25~4.0', () {
      final over =
          HttpTtsProvider(baseUrl: 'x', apiKey: 'k', model: 'm', rate: 5.0);
      expect(over.buildBody('hi')['speed'], 4.0);
      final under =
          HttpTtsProvider(baseUrl: 'x', apiKey: 'k', model: 'm', rate: 0.1);
      expect(under.buildBody('hi')['speed'], 0.25);
    });

    test('空 voiceId 时默认 alloy', () {
      final p = HttpTtsProvider(baseUrl: 'x', apiKey: 'k', model: 'm');
      expect(p.voiceId, 'alloy');
    });
  });
}
