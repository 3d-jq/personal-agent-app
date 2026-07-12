import '../services/token_usage_tracker.dart';

/// 模型参考单价（USD / 1M tokens；按次模式用 [pricePerRequest]）。
///
/// 重要：这是「UI 层参考默认值」，仅用于未手动配置单价时给出可参考的成本估算，
/// 全部可由用户在 Token 统计页编辑覆盖。本文件是 UI 展示用的参考数据，
/// 不涉及任何服务/逻辑层默认值（服务层 [TokenUsageTracker] 对模型名无知）。
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
const Map<String, DefaultModelPrice> modelPricingDefaults = {
  // ── DeepSeek ──
  'deepseek-chat': DefaultModelPrice(
    inputPricePerMillion: 0.27,
    cachedInputPricePerMillion: 0.07,
    outputPricePerMillion: 1.10,
  ),
  'deepseek-reasoner': DefaultModelPrice(
    inputPricePerMillion: 0.55,
    cachedInputPricePerMillion: 0.14,
    outputPricePerMillion: 2.19,
  ),
  'deepseek-v3': DefaultModelPrice(
    inputPricePerMillion: 0.27,
    cachedInputPricePerMillion: 0.07,
    outputPricePerMillion: 1.10,
  ),
  // ── OpenAI ──
  'gpt-4o': DefaultModelPrice(
    inputPricePerMillion: 2.50,
    cachedInputPricePerMillion: 1.25,
    outputPricePerMillion: 10.00,
  ),
  'gpt-4o-mini': DefaultModelPrice(
    inputPricePerMillion: 0.15,
    cachedInputPricePerMillion: 0.075,
    outputPricePerMillion: 0.60,
  ),
  'gpt-4.1': DefaultModelPrice(
    inputPricePerMillion: 2.00,
    cachedInputPricePerMillion: 0.50,
    outputPricePerMillion: 8.00,
  ),
  'gpt-4.1-mini': DefaultModelPrice(
    inputPricePerMillion: 0.40,
    cachedInputPricePerMillion: 0.10,
    outputPricePerMillion: 1.60,
  ),
  'o3-mini': DefaultModelPrice(
    inputPricePerMillion: 1.10,
    cachedInputPricePerMillion: 0.55,
    outputPricePerMillion: 4.40,
  ),
  // ── Anthropic ──
  'claude-3-5-sonnet': DefaultModelPrice(
    inputPricePerMillion: 3.00,
    cachedInputPricePerMillion: 0.30,
    outputPricePerMillion: 15.00,
  ),
  'claude-3-7-sonnet': DefaultModelPrice(
    inputPricePerMillion: 3.00,
    cachedInputPricePerMillion: 0.30,
    outputPricePerMillion: 15.00,
  ),
  'claude-3-haiku': DefaultModelPrice(
    inputPricePerMillion: 0.25,
    cachedInputPricePerMillion: 0.03,
    outputPricePerMillion: 1.25,
  ),
  'claude-sonnet-4': DefaultModelPrice(
    inputPricePerMillion: 3.00,
    cachedInputPricePerMillion: 0.30,
    outputPricePerMillion: 15.00,
  ),
  // ── Google ──
  'gemini-1.5-pro': DefaultModelPrice(
    inputPricePerMillion: 1.25,
    cachedInputPricePerMillion: 0.31,
    outputPricePerMillion: 5.00,
  ),
  'gemini-2.0-flash': DefaultModelPrice(
    inputPricePerMillion: 0.10,
    cachedInputPricePerMillion: 0.025,
    outputPricePerMillion: 0.40,
  ),
  'gemini-2.5-pro': DefaultModelPrice(
    inputPricePerMillion: 1.25,
    cachedInputPricePerMillion: 0.31,
    outputPricePerMillion: 10.00,
  ),
  'gemini-2.5-flash': DefaultModelPrice(
    inputPricePerMillion: 0.30,
    cachedInputPricePerMillion: 0.075,
    outputPricePerMillion: 2.50,
  ),
  // ── 通义 / 阿里 ──
  'qwen-max': DefaultModelPrice(
    inputPricePerMillion: 0.40,
    cachedInputPricePerMillion: 0.10,
    outputPricePerMillion: 1.20,
  ),
  'qwen-plus': DefaultModelPrice(
    inputPricePerMillion: 0.08,
    cachedInputPricePerMillion: 0.02,
    outputPricePerMillion: 0.24,
  ),
  'qwen-turbo': DefaultModelPrice(
    inputPricePerMillion: 0.03,
    cachedInputPricePerMillion: 0.008,
    outputPricePerMillion: 0.09,
  ),
  // ── 智谱 GLM ──
  'glm-4': DefaultModelPrice(
    inputPricePerMillion: 0.05,
    cachedInputPricePerMillion: 0.012,
    outputPricePerMillion: 0.15,
  ),
  'glm-4-plus': DefaultModelPrice(
    inputPricePerMillion: 0.10,
    cachedInputPricePerMillion: 0.025,
    outputPricePerMillion: 0.30,
  ),
  // ── MiniMax ──
  'abab6.5s-chat': DefaultModelPrice(
    inputPricePerMillion: 0.07,
    cachedInputPricePerMillion: 0.014,
    outputPricePerMillion: 0.21,
  ),
  // ── Moonshot / Kimi ──
  'moonshot-v1-8k': DefaultModelPrice(
    inputPricePerMillion: 0.03,
    cachedInputPricePerMillion: 0.006,
    outputPricePerMillion: 0.09,
  ),
  // ── 字节豆包 ──
  'doubao-pro': DefaultModelPrice(
    inputPricePerMillion: 0.03,
    cachedInputPricePerMillion: 0.006,
    outputPricePerMillion: 0.09,
  ),
  // ── 火山方舟（按次计费示例）──
  'ep-xxxx': DefaultModelPrice(
    mode: BillingMode.count,
    pricePerRequest: 0.001,
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
