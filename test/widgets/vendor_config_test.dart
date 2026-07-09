import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/widgets/vendor_config.dart';

void main() {
  group('VendorConfig.protocol', () {
    test('默认 protocol 为 openai', () {
      final v = VendorConfig(
        id: '1',
        name: 'DeepSeek',
        apiKey: 'k',
        baseUrl: 'u',
      );
      expect(v.protocol, 'openai');
      expect(v.isAnthropic, isFalse);
    });

    test('显式指定 anthropic', () {
      final v = VendorConfig(
        id: '1',
        name: 'Claude',
        apiKey: 'k',
        baseUrl: 'u',
        protocol: 'anthropic',
      );
      expect(v.protocol, 'anthropic');
      expect(v.isAnthropic, isTrue);
    });

    test('toJson / fromJson round-trip 保留 protocol', () {
      final v = VendorConfig(
        id: '1',
        name: 'Claude',
        apiKey: 'k',
        baseUrl: 'u',
        model: 'm',
        protocol: 'anthropic',
      );
      final j = v.toJson();
      expect(j['protocol'], 'anthropic');
      final back = VendorConfig.fromJson(j);
      expect(back.protocol, 'anthropic');
      expect(back.isAnthropic, isTrue);
      expect(back.model, 'm');
    });

    test('旧数据（无 protocol 字段）fromJson 默认 openai', () {
      final legacy = <String, dynamic>{
        'id': '1',
        'name': 'DeepSeek',
        'apiKey': 'k',
        'baseUrl': 'u',
        'model': 'm',
        'isBuiltIn': false,
      };
      final v = VendorConfig.fromJson(legacy);
      expect(v.protocol, 'openai');
      expect(v.isAnthropic, isFalse);
    });

    test('copyWith 可改 protocol 且不改动其它字段', () {
      final v = VendorConfig(
        id: '1',
        name: 'n',
        apiKey: 'k',
        baseUrl: 'u',
      );
      final c = v.copyWith(protocol: 'anthropic');
      expect(c.protocol, 'anthropic');
      expect(c.name, 'n');
      expect(c.apiKey, 'k');
    });
  });
}
