import '../services/token_usage_tracker.dart';

/// 模型参考单价（CNY / 1M tokens；按次模式用 [pricePerRequest]）。
///
/// 全部是 UI 层参考默认值，仅用于未手动配置单价时给出可参考的成本估算，
/// 全部可由用户在 Token 统计页编辑覆盖。服务层 [TokenUsageTracker] 对模型名无知。
/// 价格随厂商调整，仅供参考。
class DefaultModelPrice {
  const DefaultModelPrice({
    this.mode = BillingMode.token,
    this.inputPricePerMillion = 0.0,
    this.cachedInputPricePerMillion = 0.0,
    this.outputPricePerMillion = 0.0,
    this.pricePerRequest = 0.0,
  });

  final BillingMode mode;
  final double inputPricePerMillion;
  final double cachedInputPricePerMillion;
  final double outputPricePerMillion;
  final double pricePerRequest;

  PriceConfig toPriceConfig() => PriceConfig(
        mode: mode,
        inputPricePerMillion: inputPricePerMillion,
        cachedInputPricePerMillion: cachedInputPricePerMillion,
        outputPricePerMillion: outputPricePerMillion,
        pricePerRequest: pricePerRequest,
      );
}

/// 常见模型的参考单价表（key = 模型名，精确匹配优先，其次子串回落）。
/// 价格为 CNY / 1M tokens。
const Map<String, DefaultModelPrice> modelPricingDefaults = {
  // ── DeepSeek ──
  'deepseek-chat': DefaultModelPrice(
    inputPricePerMillion: 1.94,
    cachedInputPricePerMillion: 0.50,
    outputPricePerMillion: 7.92,
  ),
  'deepseek-reasoner': DefaultModelPrice(
    inputPricePerMillion: 3.96,
    cachedInputPricePerMillion: 1.01,
    outputPricePerMillion: 15.77,
  ),
  'deepseek-v3': DefaultModelPrice(
    inputPricePerMillion: 1.94,
    cachedInputPricePerMillion: 0.50,
    outputPricePerMillion: 7.92,
  ),
  // ── OpenAI ──
  'gpt-4o': DefaultModelPrice(
    inputPricePerMillion: 18.00,
    cachedInputPricePerMillion: 9.00,
    outputPricePerMillion: 72.00,
  ),
  'gpt-4o-mini': DefaultModelPrice(
    inputPricePerMillion: 1.08,
    cachedInputPricePerMillion: 0.54,
    outputPricePerMillion: 4.32,
  ),
  'gpt-4.1': DefaultModelPrice(
    inputPricePerMillion: 14.40,
    cachedInputPricePerMillion: 3.60,
    outputPricePerMillion: 57.60,
  ),
  'gpt-4.1-mini': DefaultModelPrice(
    inputPricePerMillion: 2.88,
    cachedInputPricePerMillion: 0.72,
    outputPricePerMillion: 11.52,
  ),
  'o3-mini': DefaultModelPrice(
    inputPricePerMillion: 7.92,
    cachedInputPricePerMillion: 3.96,
    outputPricePerMillion: 31.68,
  ),
  // ── Anthropic ──
  'claude-3-5-sonnet': DefaultModelPrice(
    inputPricePerMillion: 21.60,
    cachedInputPricePerMillion: 2.16,
    outputPricePerMillion: 108.00,
  ),
  'claude-3-7-sonnet': DefaultModelPrice(
    inputPricePerMillion: 21.60,
    cachedInputPricePerMillion: 2.16,
    outputPricePerMillion: 108.00,
  ),
  'claude-3-haiku': DefaultModelPrice(
    inputPricePerMillion: 1.80,
    cachedInputPricePerMillion: 0.22,
    outputPricePerMillion: 9.00,
  ),
  'claude-sonnet-4': DefaultModelPrice(
    inputPricePerMillion: 21.60,
    cachedInputPricePerMillion: 2.16,
    outputPricePerMillion: 108.00,
  ),
  // ── Google ──
  'gemini-1.5-pro': DefaultModelPrice(
    inputPricePerMillion: 9.00,
    cachedInputPricePerMillion: 2.23,
    outputPricePerMillion: 36.00,
  ),
  'gemini-2.0-flash': DefaultModelPrice(
    inputPricePerMillion: 0.72,
    cachedInputPricePerMillion: 0.18,
    outputPricePerMillion: 2.88,
  ),
  'gemini-2.5-pro': DefaultModelPrice(
    inputPricePerMillion: 9.00,
    cachedInputPricePerMillion: 2.23,
    outputPricePerMillion: 72.00,
  ),
  'gemini-2.5-flash': DefaultModelPrice(
    inputPricePerMillion: 2.16,
    cachedInputPricePerMillion: 0.54,
    outputPricePerMillion: 18.00,
  ),
  // ── 通义 / 阿里 ──
  'qwen-max': DefaultModelPrice(
    inputPricePerMillion: 2.88,
    cachedInputPricePerMillion: 0.72,
    outputPricePerMillion: 8.64,
  ),
  'qwen-plus': DefaultModelPrice(
    inputPricePerMillion: 0.58,
    cachedInputPricePerMillion: 0.14,
    outputPricePerMillion: 1.73,
  ),
  'qwen-turbo': DefaultModelPrice(
    inputPricePerMillion: 0.22,
    cachedInputPricePerMillion: 0.06,
    outputPricePerMillion: 0.65,
  ),
  // ── 智谱 GLM ──
  'glm-4': DefaultModelPrice(
    inputPricePerMillion: 0.36,
    cachedInputPricePerMillion: 0.09,
    outputPricePerMillion: 1.08,
  ),
  'glm-4-plus': DefaultModelPrice(
    inputPricePerMillion: 0.72,
    cachedInputPricePerMillion: 0.18,
    outputPricePerMillion: 2.16,
  ),
  // ── MiniMax ──
  'abab6.5s-chat': DefaultModelPrice(
    inputPricePerMillion: 0.50,
    cachedInputPricePerMillion: 0.10,
    outputPricePerMillion: 1.51,
  ),
  // ── Moonshot / Kimi ──
  'moonshot-v1-8k': DefaultModelPrice(
    inputPricePerMillion: 0.22,
    cachedInputPricePerMillion: 0.04,
    outputPricePerMillion: 0.65,
  ),
  // ── 字节豆包 ──
  'doubao-pro': DefaultModelPrice(
    inputPricePerMillion: 0.22,
    cachedInputPricePerMillion: 0.04,
    outputPricePerMillion: 0.65,
  ),
  // ── 火山方舟（按次计费示例）──
  'ep-xxxx': DefaultModelPrice(
    mode: BillingMode.count,
    pricePerRequest: 0.007,
  ),
};

/// 取模型参考单价：精确匹配 → 子串回落 → 全 0（需用户自配）。
DefaultModelPrice defaultPriceForModel(String model) {
  final exact = modelPricingDefaults[model];
  if (exact != null) return exact;
  final lower = model.toLowerCase();
  for (final e in modelPricingDefaults.entries) {
    if (lower.contains(e.key.toLowerCase())) return e.value;
  }
  return const DefaultModelPrice();
}

/// 取模型参考单价，封装为 [PriceConfig]（供 [TokenUsageTracker] 计算与 UI 编辑初值）。
PriceConfig defaultPriceConfig(String model) =>
    defaultPriceForModel(model).toPriceConfig();
