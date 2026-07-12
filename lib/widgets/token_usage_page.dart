import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../core/design_tokens.dart';
import '../services/token_usage_tracker.dart';
import 'common_widgets.dart';
import 'model_pricing_defaults.dart';

/// Token 消耗统计（借鉴 Operit TokenUsageStatisticsScreen，全量成本核算）。
///
/// - 顶部 USD→¥ 汇率卡（默认 7.2，可编辑）
/// - 汇总卡：总 token / 输入·输出·缓存 / 请求次数 / 总成本（¥ 与 $）
/// - 模型用量分布：按 (厂商,模型) 的 token 占比
/// - 每模型卡：token 明细 + 成本 + 单价（点击编辑，按次/按 token 两种计费）
/// - 清空全部 / 单模型清空（带确认）
class TokenUsagePage extends StatefulWidget {
  const TokenUsagePage({super.key});

  @override
  State<TokenUsagePage> createState() => _TokenUsagePageState();
}

class _TokenUsagePageState extends State<TokenUsagePage> {
  final _tracker = tokenTracker;
  late final TextEditingController _rateC;

  @override
  void initState() {
    super.initState();
    _rateC = TextEditingController(
      text: _tracker.usdToCnyRate.toStringAsFixed(2),
    );
    _tracker.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _tracker.removeListener(_onUpdate);
    _rateC.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final rate = _tracker.usdToCnyRate;
    final entries = _tracker.entries;
    final totalTokens = _tracker.totalTokens;

    // 按模型成本汇总（USD→¥）。
    final modelCosts = <String, double>{};
    var totalCostUsd = 0.0;
    for (final e in entries) {
      final price =
          _tracker.priceOf(e.key) ?? defaultPriceConfig(_modelOf(e.key));
      final c = computeCostUsd(e.value, price);
      modelCosts[e.key] = c;
      totalCostUsd += c;
    }
    final totalCostCny = totalCostUsd * rate;

    // 分布：每模型 (input+output) token 占比。
    final dist = entries
        .map((e) => MapEntry(e.key, e.value.totalTokens))
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: nc.bgSubtle,
      appBar: AppTopBar(
        title: 'Token 消耗统计',
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              icon: Icon(Icons.restart_alt, color: nc.error),
              onPressed: _confirmResetAll,
            ),
        ],
      ),
      body: entries.isEmpty
          ? _Empty(nc: nc)
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceToken.lg,
                vertical: SpaceToken.lg,
              ),
              children: [
                _RateCard(nc: nc, rateC: _rateC, onSave: _saveRate),
                const SizedBox(height: SpaceToken.xl),
                _SummaryCard(
                  nc: nc,
                  totalTokens: totalTokens,
                  inputTokens: _tracker.totalInputTokens,
                  outputTokens: _tracker.totalOutputTokens,
                  cachedTokens: _tracker.totalCachedInputTokens,
                  requests: _tracker.totalRequests,
                  costCny: totalCostCny,
                  costUsd: totalCostUsd,
                ),
                if (dist.isNotEmpty) ...[
                  const SizedBox(height: SpaceToken.xl),
                  _DistributionSection(nc: nc, items: dist, total: totalTokens),
                ],
                const SizedBox(height: SpaceToken.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('模型明细',
                        style: TextStyle(
                            fontSize: FontToken.title,
                            fontWeight: WeightToken.semibold,
                            color: nc.textPrimary)),
                    Text('点击卡片编辑单价',
                        style: TextStyle(
                            fontSize: FontToken.small,
                            color: nc.textSecondary)),
                  ],
                ),
                const SizedBox(height: SpaceToken.md),
                ...entries.map((e) {
                  final price = _tracker.priceOf(e.key) ??
                      defaultPriceConfig(_modelOf(e.key));
                  final costUsd = modelCosts[e.key] ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: SpaceToken.md),
                    child: _ModelCard(
                      nc: nc,
                      keyName: e.key,
                      vendor: _vendorOf(e.key),
                      model: _modelOf(e.key),
                      record: e.value,
                      price: price,
                      rate: rate,
                      costCny: costUsd * rate,
                      costUsd: costUsd,
                      onEdit: () => _editPrice(e.key, _modelOf(e.key)),
                      onReset: () => _confirmResetModel(e.key, _modelOf(e.key)),
                    ),
                  );
                }),
                const SizedBox(height: SpaceToken.x3),
              ],
            ),
    );
  }

  String _vendorOf(String key) => _tracker.splitKey(key).first;
  String _modelOf(String key) =>
      _tracker.splitKey(key).length > 1 ? _tracker.splitKey(key)[1] : '';

  void _saveRate() {
    final v = double.tryParse(_rateC.text.trim());
    if (v != null && v > 0) {
      _tracker.setUsdToCnyRate(v);
      if (mounted) setState(() {});
    }
  }

  void _confirmResetAll() {
    final nc = AgentColors.of(context);
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: nc.surface,
        title: Text('清空全部统计', style: TextStyle(color: nc.textPrimary)),
        content: Text('将清空所有厂商/模型的 token 与成本统计（单价与汇率保留）。',
            style: TextStyle(color: nc.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('取消', style: TextStyle(color: nc.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              _tracker.clearAll();
              Navigator.pop(c);
            },
            child: Text('清空', style: TextStyle(color: nc.error)),
          ),
        ],
      ),
    );
  }

  void _confirmResetModel(String key, String model) {
    final nc = AgentColors.of(context);
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: nc.surface,
        title: Text('清空该模型', style: TextStyle(color: nc.textPrimary)),
        content: Text('将清空「$model」的 token 与成本统计（单价保留）。',
            style: TextStyle(color: nc.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('取消', style: TextStyle(color: nc.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final parts = _tracker.splitKey(key);
              if (parts.length >= 2) {
                _tracker.clearModel(parts[0], parts[1]);
              }
              Navigator.pop(c);
            },
            child: Text('清空', style: TextStyle(color: nc.error)),
          ),
        ],
      ),
    );
  }

  void _editPrice(String key, String model) {
    final nc = AgentColors.of(context);
    final parts = _tracker.splitKey(key);
    final vendor = parts.isNotEmpty ? parts[0] : '';
    final stored = _tracker.priceOf(key);
    final base = stored ?? defaultPriceConfig(model);
    final rate = _tracker.usdToCnyRate;
    // 计费模式放在 builder 闭包之外，避免 StatefulBuilder 每次重建时被重置。
    var mode = base.mode;

    showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setD) {
          // 初始以 ¥ 展示（USD×rate），保存时折算回 USD。
          final inputC = TextEditingController(
            text: _fmtEditable(_toCny(base.inputPricePerMillion, rate)),
          );
          final cachedC = TextEditingController(
            text: _fmtEditable(_toCny(base.cachedInputPricePerMillion, rate)),
          );
          final outputC = TextEditingController(
            text: _fmtEditable(_toCny(base.outputPricePerMillion, rate)),
          );
          final perRequestC = TextEditingController(
            text: _fmtEditable(_toCny(base.pricePerRequest, rate)),
          );

          void save() {
            final price = PriceConfig(
              mode: mode,
              inputPricePerMillion:
                  _fromCny(double.tryParse(inputC.text) ?? 0, rate),
              cachedInputPricePerMillion:
                  _fromCny(double.tryParse(cachedC.text) ?? 0, rate),
              outputPricePerMillion:
                  _fromCny(double.tryParse(outputC.text) ?? 0, rate),
              pricePerRequest:
                  _fromCny(double.tryParse(perRequestC.text) ?? 0, rate),
            );
            if (vendor.isNotEmpty && model.isNotEmpty) {
              _tracker.setPrice(vendor, model, price);
            }
            Navigator.pop(ctx);
          }

          return AlertDialog(
            backgroundColor: nc.surface,
            title: Text('编辑单价 · $model',
                style: TextStyle(color: nc.textPrimary)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('计费方式',
                      style: TextStyle(
                          fontSize: FontToken.small,
                          color: nc.textSecondary)),
                  const SizedBox(height: SpaceToken.sm),
                  SegmentedButton<BillingMode>(
                    selected: {mode},
                    onSelectionChanged: (s) {
                      if (s.isNotEmpty) setD(() => mode = s.first);
                    },
                    segments: const [
                      ButtonSegment(
                        value: BillingMode.token,
                        label: Text('按 token'),
                      ),
                      ButtonSegment(
                        value: BillingMode.count,
                        label: Text('按次'),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpaceToken.md),
                  Text('单价以 ¥ 填写（自动按汇率折算 USD 存储）',
                      style: TextStyle(
                          fontSize: FontToken.small,
                          color: nc.textSecondary)),
                  const SizedBox(height: SpaceToken.md),
                  if (mode == BillingMode.token) ...[
                    _PriceField(
                      nc: nc,
                      label: '输入单价 (¥/1M)',
                      controller: inputC,
                    ),
                    _PriceField(
                      nc: nc,
                      label: '缓存输入单价 (¥/1M)',
                      controller: cachedC,
                    ),
                    _PriceField(
                      nc: nc,
                      label: '输出单价 (¥/1M)',
                      controller: outputC,
                    ),
                  ] else
                    _PriceField(
                      nc: nc,
                      label: '每次请求价 (¥)',
                      controller: perRequestC,
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('取消', style: TextStyle(color: nc.textSecondary)),
              ),
              TextButton(
                onPressed: save,
                child: Text('保存', style: TextStyle(color: nc.primary)),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── 汇率卡 ──

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.nc,
    required this.rateC,
    required this.onSave,
  });
  final AgentColors nc;
  final TextEditingController rateC;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ElevatedCard(
      nc: nc,
      shadow: nc.shadowSm,
      child: Padding(
        padding: const EdgeInsets.all(SpaceToken.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('汇率（USD → ¥）',
                style: TextStyle(
                    fontSize: FontToken.body,
                    fontWeight: WeightToken.medium,
                    color: nc.textPrimary)),
            const SizedBox(height: SpaceToken.sm),
            Text('用于将 USD 单价/成本折算成人民币展示。',
                style: TextStyle(
                    fontSize: FontToken.small, color: nc.textSecondary)),
            const SizedBox(height: SpaceToken.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: rateC,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: nc.textPrimary),
                    decoration: InputDecoration(
                      labelText: '1 USD = ¥',
                      labelStyle:
                          TextStyle(color: nc.textSecondary, fontSize: FontToken.small),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: nc.divider),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: SpaceToken.md,
                        vertical: SpaceToken.sm,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: SpaceToken.md),
                FilledButton(onPressed: onSave, child: const Text('保存')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 汇总卡 ──

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.nc,
    required this.totalTokens,
    required this.inputTokens,
    required this.outputTokens,
    required this.cachedTokens,
    required this.requests,
    required this.costCny,
    required this.costUsd,
  });
  final AgentColors nc;
  final int totalTokens;
  final int inputTokens;
  final int outputTokens;
  final int cachedTokens;
  final int requests;
  final double costCny;
  final double costUsd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: nc.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(SpaceToken.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('消耗汇总',
              style: TextStyle(
                  fontSize: FontToken.title,
                  fontWeight: WeightToken.bold,
                  color: nc.onPrimary)),
          const SizedBox(height: SpaceToken.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Metric(
                nc: nc,
                label: '总 Token',
                value: _fmtInt(totalTokens),
              ),
              _Metric(
                nc: nc,
                label: '请求次数',
                value: _fmtInt(requests),
              ),
              _Metric(
                nc: nc,
                label: '总成本',
                value: _fmtCny(costCny),
                sub: _fmtUsd(costUsd),
              ),
            ],
          ),
          const SizedBox(height: SpaceToken.md),
          const Divider(height: 0.5),
          const SizedBox(height: SpaceToken.sm),
          _Line(nc: nc, label: '输入 Token', value: _fmtInt(inputTokens)),
          _Line(nc: nc, label: '输出 Token', value: _fmtInt(outputTokens)),
          if (cachedTokens > 0)
            _Line(nc: nc, label: '缓存命中 Token', value: _fmtInt(cachedTokens)),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.nc,
    required this.label,
    required this.value,
    this.sub,
  });
  final AgentColors nc;
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final secondary = nc.onPrimary.withValues(alpha: 0.75);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: FontToken.small, color: secondary)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: WeightToken.bold,
                  color: nc.onPrimary)),
          if (sub != null)
            Text(sub!,
                style: TextStyle(fontSize: 11, color: secondary)),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.nc,
    required this.label,
    required this.value,
  });
  final AgentColors nc;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: FontToken.body, color: nc.onPrimary)),
            Text(value,
                style: TextStyle(
                    fontSize: FontToken.body,
                    fontWeight: WeightToken.medium,
                    color: nc.onPrimary)),
          ],
        ),
      );
}

// ── 分布 ──

class _DistributionSection extends StatelessWidget {
  const _DistributionSection({
    required this.nc,
    required this.items,
    required this.total,
  });
  final AgentColors nc;
  final List<MapEntry<String, int>> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    final palette = [
      nc.primary,
      nc.success,
      nc.warning,
      nc.error,
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('模型用量分布',
            style: TextStyle(
                fontSize: FontToken.title,
                fontWeight: WeightToken.semibold,
                color: nc.textPrimary)),
        const SizedBox(height: SpaceToken.md),
        ...items.asMap().entries.map((e) {
          final idx = e.key;
          final entry = e.value;
          final pct = total > 0 ? entry.value / total : 0.0;
          final color = palette[idx % palette.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: SpaceToken.sm),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: SpaceToken.sm),
                Expanded(
                  flex: 3,
                  child: Text(
                    _modelOf(entry.key),
                    style: TextStyle(fontSize: FontToken.small, color: nc.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: SpaceToken.sm),
                Expanded(
                  flex: 5,
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: nc.divider,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: SpaceToken.sm),
                SizedBox(
                  width: 44,
                  child: Text('${(pct * 100).toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: FontToken.small, color: nc.textSecondary)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _modelOf(String key) {
    final parts = key.split('~');
    return parts.length > 1 ? parts[1] : key;
  }
}

// ── 模型卡 ──

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.nc,
    required this.keyName,
    required this.vendor,
    required this.model,
    required this.record,
    required this.price,
    required this.rate,
    required this.costCny,
    required this.costUsd,
    required this.onEdit,
    required this.onReset,
  });
  final AgentColors nc;
  final String keyName;
  final String vendor;
  final String model;
  final TokenUsageRecord record;
  final PriceConfig price;
  final double rate;
  final double costCny;
  final double costUsd;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final isToken = price.mode == BillingMode.token;
    return Material(
      color: nc.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: nc.divider, width: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(SpaceToken.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(model,
                            style: TextStyle(
                                fontSize: FontToken.body,
                                fontWeight: WeightToken.semibold,
                                color: nc.textPrimary)),
                        if (vendor.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(vendor,
                                style: TextStyle(
                                    fontSize: FontToken.small, color: nc.textSecondary)),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: onReset,
                        icon: Icon(Icons.restart_alt,
                            size: 18, color: nc.error),
                        tooltip: '清空该模型',
                        visualDensity: VisualDensity.compact,
                      ),
                      Icon(Icons.edit, size: 16, color: nc.textSecondary),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: SpaceToken.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Cell(nc: nc, label: '请求', value: _fmtInt(record.requestCount)),
                  _Cell(nc: nc, label: '输入', value: _fmtInt(record.inputTokens)),
                  _Cell(nc: nc, label: '输出', value: _fmtInt(record.outputTokens)),
                  if (record.cachedInputTokens > 0)
                    _Cell(
                        nc: nc,
                        label: '缓存',
                        value: _fmtInt(record.cachedInputTokens)),
                ],
              ),
              const SizedBox(height: SpaceToken.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('成本',
                          style: TextStyle(
                              fontSize: FontToken.small, color: nc.textSecondary)),
                      Text(_fmtCny(costCny),
                          style: TextStyle(
                              fontSize: FontToken.body,
                              fontWeight: WeightToken.bold,
                              color: nc.primary)),
                      Text(_fmtUsd(costUsd),
                          style: TextStyle(
                              fontSize: 11, color: nc.textSecondary)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpaceToken.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isToken ? nc.brandSoft : nc.primarySurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(isToken ? '按 token' : '按次',
                        style: TextStyle(
                            fontSize: 11,
                            color: isToken
                                ? nc.primary
                                : nc.textSecondary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.nc,
    required this.label,
    required this.value,
  });
  final AgentColors nc;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: FontToken.small, color: nc.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: FontToken.body,
                  fontWeight: WeightToken.medium,
                  color: nc.textPrimary)),
        ],
      );
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.nc,
    required this.label,
    required this.controller,
  });
  final AgentColors nc;
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: SpaceToken.md),
        child: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: nc.textPrimary),
          decoration: InputDecoration(
            labelText: label,
            labelStyle:
                TextStyle(color: nc.textSecondary, fontSize: FontToken.small),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: nc.divider),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: SpaceToken.md,
              vertical: SpaceToken.sm,
            ),
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.nc});
  final AgentColors nc;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics,
                size: 48, color: nc.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('暂无 token 统计',
                style: TextStyle(color: nc.textSecondary, fontSize: 14)),
            const SizedBox(height: 4),
            Text('发起对话后自动按厂商+模型累计',
                style: TextStyle(fontSize: 12, color: nc.textSecondary.withValues(alpha: 0.5))),
          ],
        ),
      );
}

// ── 格式化助手 ──

String _fmtInt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

String _fmtCny(double v) => '¥${v.toStringAsFixed(2)}';
String _fmtUsd(double v) => '\$${v.toStringAsFixed(4)}';

double _toCny(double usd, double rate) => usd * rate;
double _fromCny(double cny, double rate) => rate > 0 ? cny / rate : 0.0;

String _fmtEditable(double v) => v.toStringAsFixed(4).replaceAllMapped(
    RegExp(r'0+$'), (m) => '').replaceAll(RegExp(r'\.$'), '');
