import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'log_service.dart';

/// 计费模式：按 token 计费 / 按次计费。
enum BillingMode {
  /// 按 token：input / cachedInput / output 分别计价（单价 per 1M）。
  token,

  /// 按次：每次请求固定价（pricePerRequest）。
  count;

  String get name => switch (this) {
        BillingMode.token => 'token',
        BillingMode.count => 'count',
      };

  static BillingMode fromName(String? s) =>
      s == 'count' ? BillingMode.count : BillingMode.token;
}

/// 单价配置（均以 USD 计价，per 1M tokens；按次模式用 [pricePerRequest]）。
///
/// 此为「持久化的用户配置」——默认空（未配置时回落到 UI 层参考价，
/// 见 [ModelPricingDefaults]）。本服务层不内置任何模型名/价格。
class PriceConfig {
  const PriceConfig({
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

  PriceConfig copyWith({
    BillingMode? mode,
    double? inputPricePerMillion,
    double? cachedInputPricePerMillion,
    double? outputPricePerMillion,
    double? pricePerRequest,
  }) =>
      PriceConfig(
        mode: mode ?? this.mode,
        inputPricePerMillion:
            inputPricePerMillion ?? this.inputPricePerMillion,
        cachedInputPricePerMillion:
            cachedInputPricePerMillion ?? this.cachedInputPricePerMillion,
        outputPricePerMillion:
            outputPricePerMillion ?? this.outputPricePerMillion,
        pricePerRequest: pricePerRequest ?? this.pricePerRequest,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'inputPricePerMillion': inputPricePerMillion,
        'cachedInputPricePerMillion': cachedInputPricePerMillion,
        'outputPricePerMillion': outputPricePerMillion,
        'pricePerRequest': pricePerRequest,
      };

  factory PriceConfig.fromJson(Map<String, dynamic> j) => PriceConfig(
        mode: BillingMode.fromName(j['mode'] as String?),
        inputPricePerMillion:
            (j['inputPricePerMillion'] as num?)?.toDouble() ?? 0.0,
        cachedInputPricePerMillion:
            (j['cachedInputPricePerMillion'] as num?)?.toDouble() ?? 0.0,
        outputPricePerMillion:
            (j['outputPricePerMillion'] as num?)?.toDouble() ?? 0.0,
        pricePerRequest: (j['pricePerRequest'] as num?)?.toDouble() ?? 0.0,
      );
}

/// 某 (厂商, 模型) 的累计 token 用量。
class TokenUsageRecord {
  TokenUsageRecord({
    this.inputTokens = 0,
    this.cachedInputTokens = 0,
    this.outputTokens = 0,
    this.requestCount = 0,
  });

  int inputTokens;
  int cachedInputTokens;
  int outputTokens;
  int requestCount;

  int get totalTokens => inputTokens + outputTokens;

  void add({
    required int inputTokens,
    required int outputTokens,
    int cachedInputTokens = 0,
  }) {
    this.inputTokens += inputTokens;
    this.outputTokens += outputTokens;
    this.cachedInputTokens += cachedInputTokens;
    requestCount += 1;
  }

  Map<String, dynamic> toJson() => {
        'inputTokens': inputTokens,
        'cachedInputTokens': cachedInputTokens,
        'outputTokens': outputTokens,
        'requestCount': requestCount,
      };

  factory TokenUsageRecord.fromJson(Map<String, dynamic> j) => TokenUsageRecord(
        inputTokens: (j['inputTokens'] as num?)?.toInt() ?? 0,
        cachedInputTokens: (j['cachedInputTokens'] as num?)?.toInt() ?? 0,
        outputTokens: (j['outputTokens'] as num?)?.toInt() ?? 0,
        requestCount: (j['requestCount'] as num?)?.toInt() ?? 0,
      );
}

/// 纯函数：按 [PriceConfig] 计算单条记录的 USD 成本。
///
/// - token 模式：非缓存 input + output + cachedInput 分别计价。
/// - count 模式：requestCount × pricePerRequest。
double computeCostUsd(TokenUsageRecord r, PriceConfig p) {
  if (p.mode == BillingMode.count) {
    return r.requestCount * p.pricePerRequest;
  }
  final nonCachedInput = (r.inputTokens - r.cachedInputTokens).clamp(0, r.inputTokens);
  final inputCost = nonCachedInput / 1e6 * p.inputPricePerMillion;
  final cachedCost = r.cachedInputTokens / 1e6 * p.cachedInputPricePerMillion;
  final outputCost = r.outputTokens / 1e6 * p.outputPricePerMillion;
  return inputCost + cachedCost + outputCost;
}

/// Token 用量追踪（借鉴 Operit TokenUsageStatisticsScreen，按厂商+模型核算成本）。
///
/// - 全量持久化到本地 JSON（增量累加，不依赖服务端返回历史）。
/// - 单价（USD）由用户配置；未配置时回落 UI 层参考价。
/// - 暴露 [ChangeNotifier]，UI 可实时刷新汇总。
class TokenUsageTracker {
  TokenUsageTracker._();

  /// USD → CNY 汇率（默认 7.2，可编辑；用于把 USD 成本折算成 ¥ 展示）。
  double usdToCnyRate = 7.2;

  final Map<String, TokenUsageRecord> _records = {};
  final Map<String, PriceConfig> _prices = {};

  bool _loaded = false;
  Timer? _saveTimer;

  // ── key 约定 ──
  static String key(String vendor, String model) => '$vendor~$model';
  List<String> splitKey(String k) => k.split('~');

  // ── 查询 ──
  List<MapEntry<String, TokenUsageRecord>> get entries =>
      _records.entries.toList();

  TokenUsageRecord? recordOf(String k) => _records[k];

  PriceConfig? priceOf(String k) => _prices[k];

  int get totalInputTokens =>
      _records.values.fold(0, (s, r) => s + r.inputTokens);
  int get totalOutputTokens =>
      _records.values.fold(0, (s, r) => s + r.outputTokens);
  int get totalCachedInputTokens =>
      _records.values.fold(0, (s, r) => s + r.cachedInputTokens);
  int get totalTokens => totalInputTokens + totalOutputTokens;
  int get totalRequests =>
      _records.values.fold(0, (s, r) => s + r.requestCount);

  int inputTokensOf(String k) => _records[k]?.inputTokens ?? 0;
  int outputTokensOf(String k) => _records[k]?.outputTokens ?? 0;
  int cachedInputTokensOf(String k) => _records[k]?.cachedInputTokens ?? 0;
  int requestCountOf(String k) => _records[k]?.requestCount ?? 0;

  // ── 写入 ──

  /// 记录一次请求的 token 消耗（累加）。
  void record({
    required String vendor,
    required String model,
    required int inputTokens,
    required int outputTokens,
    int cachedInputTokens = 0,
  }) {
    final k = key(vendor, model);
    final r = _records.putIfAbsent(k, () => TokenUsageRecord());
    r.add(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      cachedInputTokens: cachedInputTokens,
    );
    _notify();
    _scheduleSave();
  }

  /// 设置某 (厂商,模型) 的单价配置（USD）。
  void setPrice(String vendor, String model, PriceConfig price) {
    _prices[key(vendor, model)] = price;
    _notify();
    _scheduleSave();
  }

  void setBillingMode(String vendor, String model, BillingMode mode) {
    final k = key(vendor, model);
    final cur = _prices[k] ?? const PriceConfig();
    _prices[k] = cur.copyWith(mode: mode);
    _notify();
    _scheduleSave();
  }

  void setUsdToCnyRate(double rate) {
    if (rate <= 0) return;
    usdToCnyRate = rate;
    _notify();
    _scheduleSave();
  }

  /// 清空单个 (厂商,模型) 的统计（保留其单价配置）。
  void clearModel(String vendor, String model) {
    _records.remove(key(vendor, model));
    _notify();
    _scheduleSave();
  }

  /// 清空全部统计（保留汇率与单价配置）。
  void clearAll() {
    _records.clear();
    _notify();
    _scheduleSave();
  }

  // ── 持久化 ──

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await _file();
      if (await f.exists()) {
        final d = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final rate = (d['usdToCnyRate'] as num?)?.toDouble();
        if (rate != null && rate > 0) usdToCnyRate = rate;
        final recs = d['records'];
        if (recs is Map) {
          for (final e in recs.entries) {
            if (e.value is Map) {
              _records[e.key] =
                  TokenUsageRecord.fromJson(e.value as Map<String, dynamic>);
            }
          }
        }
        final pris = d['prices'];
        if (pris is Map) {
          for (final e in pris.entries) {
            if (e.value is Map) {
              _prices[e.key] =
                  PriceConfig.fromJson(e.value as Map<String, dynamic>);
            }
          }
        }
      }
    } catch (e) {
      log.w('TokenUsageTracker', '加载 token 用量失败: $e');
    }
    _loaded = true;
  }

  Future<File> _file() async {
    final d = await getApplicationDocumentsDirectory();
    return File('${d.path}/token_usage.json');
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_save());
    });
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({
        'usdToCnyRate': usdToCnyRate,
        'records': {for (final e in _records.entries) e.key: e.value.toJson()},
        'prices': {for (final e in _prices.entries) e.key: e.value.toJson()},
      }));
    } catch (e) {
      log.w('TokenUsageTracker', '保存 token 用量失败: $e');
    }
  }

  // ── 通知 ──
  final Set<void Function()> _listeners = {};

  void _notify() {
    for (final l in _listeners) {
      l();
    }
  }

  void addListener(void Function() cb) => _listeners.add(cb);
  void removeListener(void Function() cb) => _listeners.remove(cb);

  /// 仅供测试：清空内存（不删文件）并重置汇率。
  void resetForTest() {
    _records.clear();
    _prices.clear();
    usdToCnyRate = 7.2;
    _loaded = false;
    _saveTimer?.cancel();
    _saveTimer = null;
  }
}

/// 全局实例
final tokenTracker = TokenUsageTracker._();
