import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/token_usage_tracker.dart';

/// mock path_provider 通道，避免 Windows 下挂起；落盘到真实临时目录以验证持久化。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tmp.path;
      }
      return null;
    },
  );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tok_usg_');
    tokenTracker.resetForTest();
  });

  tearDown(() {
    tokenTracker.resetForTest();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('computeCostUsd', () {
    test('token 模式：非缓存 input + cached + output 分别计价', () {
      final r = TokenUsageRecord(
        inputTokens: 2_000_000,
        cachedInputTokens: 1_000_000,
        outputTokens: 1_000_000,
      );
      const p = PriceConfig(
        mode: BillingMode.token,
        inputPricePerMillion: 2.0,
        cachedInputPricePerMillion: 1.0,
        outputPricePerMillion: 8.0,
      );
      // 非缓存 input = 1_000_000 → 2.0；cached = 1_000_000 → 1.0；output = 1_000_000 → 8.0
      expect(computeCostUsd(r, p), closeTo(11.0, 1e-9));
    });

    test('token 模式：缓存超过 input 时非缓存部分钳到 0', () {
      final r = TokenUsageRecord(
        inputTokens: 500_000,
        cachedInputTokens: 1_000_000,
        outputTokens: 0,
      );
      const p = PriceConfig(
        mode: BillingMode.token,
        inputPricePerMillion: 2.0,
        cachedInputPricePerMillion: 1.0,
      );
      // 非缓存 input 钳到 0 → 0；cached 仍按 1_000_000 → 1.0
      expect(computeCostUsd(r, p), closeTo(1.0, 1e-9));
    });

    test('count 模式：按请求次数 × 单价', () {
      final r = TokenUsageRecord(requestCount: 5);
      const p = PriceConfig(
        mode: BillingMode.count,
        pricePerRequest: 0.01,
      );
      expect(computeCostUsd(r, p), closeTo(0.05, 1e-9));
    });
  });

  group('record / 累加', () {
    test('同厂商+模型累加，不同则分别计数', () {
      tokenTracker.record(
        vendor: 'OpenAI',
        model: 'gpt-4o',
        inputTokens: 100,
        outputTokens: 200,
        cachedInputTokens: 50,
      );
      tokenTracker.record(
        vendor: 'OpenAI',
        model: 'gpt-4o',
        inputTokens: 100,
        outputTokens: 200,
        cachedInputTokens: 50,
      );
      tokenTracker.record(
        vendor: 'Anthropic',
        model: 'claude-3',
        inputTokens: 10,
        outputTokens: 20,
      );

      expect(tokenTracker.totalRequests, 3);
      expect(tokenTracker.totalInputTokens, 210);
      expect(tokenTracker.totalOutputTokens, 420);
      expect(tokenTracker.totalCachedInputTokens, 100);
      expect(tokenTracker.requestCountOf('OpenAI~gpt-4o'), 2);
      expect(tokenTracker.requestCountOf('Anthropic~claude-3'), 1);
    });

    test('key / splitKey 往返', () {
      const k = 'DeepSeek~deepseek-chat';
      expect(TokenUsageTracker.key('DeepSeek', 'deepseek-chat'), k);
      expect(tokenTracker.splitKey(k), ['DeepSeek', 'deepseek-chat']);
    });
  });

  group('单价配置', () {
    test('setPrice / priceOf / setBillingMode', () {
      tokenTracker.setPrice(
        'OpenAI',
        'gpt-4o',
        const PriceConfig(inputPricePerMillion: 5.0),
      );
      expect(tokenTracker.priceOf('OpenAI~gpt-4o')?.inputPricePerMillion, 5.0);
      tokenTracker.setBillingMode('OpenAI', 'gpt-4o', BillingMode.count);
      expect(tokenTracker.priceOf('OpenAI~gpt-4o')?.mode, BillingMode.count);
    });
  });

  group('清空', () {
    test('clearModel 删统计保留单价', () {
      tokenTracker.record(
        vendor: 'OpenAI',
        model: 'gpt-4o',
        inputTokens: 100,
        outputTokens: 100,
      );
      tokenTracker.setPrice(
        'OpenAI',
        'gpt-4o',
        const PriceConfig(inputPricePerMillion: 5.0),
      );
      tokenTracker.clearModel('OpenAI', 'gpt-4o');
      expect(tokenTracker.recordOf('OpenAI~gpt-4o'), isNull);
      expect(tokenTracker.priceOf('OpenAI~gpt-4o')?.inputPricePerMillion, 5.0);
    });

    test('clearAll 删全部统计', () {
      tokenTracker.record(
        vendor: 'OpenAI',
        model: 'gpt-4o',
        inputTokens: 100,
        outputTokens: 100,
      );
      tokenTracker.record(
        vendor: 'Anthropic',
        model: 'claude-3',
        inputTokens: 10,
        outputTokens: 20,
      );
      tokenTracker.clearAll();
      expect(tokenTracker.totalRequests, 0);
      expect(tokenTracker.totalTokens, 0);
    });
  });

  group('汇率', () {
    test('setUsdToCnyRate 忽略非正数', () {
      tokenTracker.setUsdToCnyRate(7.5);
      expect(tokenTracker.usdToCnyRate, 7.5);
      tokenTracker.setUsdToCnyRate(0);
      expect(tokenTracker.usdToCnyRate, 7.5);
      tokenTracker.setUsdToCnyRate(-1);
      expect(tokenTracker.usdToCnyRate, 7.5);
    });
  });

  group('持久化', () {
    test('record → save → 重载后数据恢复', () async {
      tokenTracker.record(
        vendor: 'OpenAI',
        model: 'gpt-4o',
        inputTokens: 123,
        outputTokens: 456,
        cachedInputTokens: 78,
      );
      tokenTracker.setPrice(
        'OpenAI',
        'gpt-4o',
        const PriceConfig(inputPricePerMillion: 5.0),
      );
      // 等防抖落盘（300ms）后再重载。
      await Future<void>.delayed(const Duration(milliseconds: 400));
      tokenTracker.resetForTest();
      await tokenTracker.load();
      expect(tokenTracker.requestCountOf('OpenAI~gpt-4o'), 1);
      expect(tokenTracker.inputTokensOf('OpenAI~gpt-4o'), 123);
      expect(tokenTracker.outputTokensOf('OpenAI~gpt-4o'), 456);
      expect(tokenTracker.cachedInputTokensOf('OpenAI~gpt-4o'), 78);
      expect(tokenTracker.priceOf('OpenAI~gpt-4o')?.inputPricePerMillion, 5.0);
    });
  });
}
