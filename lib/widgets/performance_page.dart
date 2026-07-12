import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../services/performance_monitor.dart';

class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key});

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  @override
  void initState() {
    super.initState();
    perf.addListener(_onUpdate);
  }

  @override
  void dispose() {
    perf.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final entries = perf.entries.toList().reversed.toList();
    final grouped = perf.grouped();

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: nc.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 18, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('性能', style: TextStyle(color: nc.textPrimary)),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: nc.textSecondary),
              onPressed: () {
                perf.clear();
                setState(() {});
              },
            ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart, size: 48, color: nc.textSecondary.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('暂无性能数据',
                      style: TextStyle(color: nc.textSecondary, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('发起对话后自动采集',
                      style: TextStyle(fontSize: 12, color: nc.textSecondary.withValues(alpha: 0.5))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.length + (entries.isNotEmpty ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == grouped.length) return const SizedBox(height: 32);
                final tag = grouped.keys.elementAt(i);
                final items = grouped[tag]!;
                return _Section(tag: tag, items: items.reversed.toList());
              },
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String tag;
  final List<PerfEntry> items;
  const _Section({required this.tag, required this.items});

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final icon = _tagIcon(tag);
    final color = _tagColor(tag, nc);
    final label = _tagLabel(tag);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: nc.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: nc.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 10),
                  Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: nc.textPrimary)),
                  const Spacer(),
                  Text('${items.length} 条',
                      style: TextStyle(
                          fontSize: 12, color: nc.textSecondary)),
                ],
              ),
            ),
            Divider(height: 0.5, color: nc.divider),
            SizedBox(
              height: items.length.clamp(0, 8) * 36.0 + 4,
              child: ListView.builder(
                physics: const ClampingScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, i) {
                final e = items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(e.label,
                            style: TextStyle(
                                fontSize: 13, color: nc.textPrimary)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(e.value,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          ],
        ),
      ),
    );
  }
}

IconData _tagIcon(String tag) => switch (tag) {
      'cache' => Icons.cached,
      'tool' => Icons.build_circle,
      'compress' => Icons.compress,
      'summarize' => Icons.short_text,
      'stream' => Icons.waves,
      _ => Icons.show_chart,
    };

Color _tagColor(String tag, AgentColors nc) => switch (tag) {
      'cache' => nc.primary,
      'tool' => nc.warning,
      'compress' => nc.success,
      'summarize' => const Color(0xFF8B5CF6),
      'stream' => const Color(0xFF06B6D4),
      _ => nc.textSecondary,
    };

String _tagLabel(String tag) => switch (tag) {
      'cache' => 'Prompt Cache',
      'tool' => '工具耗时',
      'compress' => '上下文压缩',
      'summarize' => '摘要统计',
      'stream' => '流式性能',
      _ => tag,
    };
