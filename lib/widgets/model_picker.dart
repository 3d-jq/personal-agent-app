import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../services/ai_service.dart';
import 'ai_settings.dart';
import 'common_widgets.dart';
import 'vendor_config.dart';

void showModelPicker(BuildContext context, AISettings s, VoidCallback cb) {
  final v = s.selectedVendor;
  if (v == null) return;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ModelPickBody(vendor: v, settings: s, onChanged: cb),
  );
}

class _ModelPickBody extends StatefulWidget {
  final VendorConfig vendor;
  final AISettings settings;
  final VoidCallback onChanged;
  const _ModelPickBody({
    required this.vendor,
    required this.settings,
    required this.onChanged,
  });
  @override
  State<_ModelPickBody> createState() => _ModelPickBodyState();
}

class _ModelPickBodyState extends State<_ModelPickBody> {
  List<String>? _fetched;
  bool _loading = false;
  String? _error;
  String _mode = 'auto'; // 'auto' | 'manual'
  late final TextEditingController _modelCtrl;

  @override
  void initState() {
    super.initState();
    _modelCtrl = TextEditingController(text: widget.vendor.model);
    _modelCtrl.addListener(_onModelChanged);
    _fetch();
  }

  void _onModelChanged() => setState(() {});

  @override
  void dispose() {
    _modelCtrl.removeListener(_onModelChanged);
    _modelCtrl.dispose();
    super.dispose();
  }

  void _useManual() {
    final m = _modelCtrl.text.trim();
    if (m.isEmpty) {
      setState(() {}); // 触发空值禁用态
      return;
    }
    HapticFeedback.lightImpact();
    widget.settings.setVendorModel(widget.vendor.id, m);
    widget.onChanged();
    Navigator.pop(context);
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _fetched = null;
    });
    try {
      final m = await AIService(
        baseUrl: widget.vendor.baseUrl,
        apiKey: widget.vendor.apiKey,
        model: '',
        isAnthropic: widget.vendor.isAnthropic,
      ).fetchModels();
      if (mounted) {
        setState(() {
          _fetched = m;
          _loading = false;
          // 当前模型不在列表里（之前手动填过）→ 自动切到手动，让用户看到自己的值
          if (widget.vendor.model.isNotEmpty && !m.contains(widget.vendor.model)) {
            _mode = 'manual';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  List<String> get _models => _fetched ?? [];
  String get _current =>
      widget.vendor.model.isNotEmpty ? widget.vendor.model : 'deepseek-chat';

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final maxH = MediaQuery.of(context).size.height * 0.55;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: nc.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '选择模型',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: nc.textPrimary,
                    ),
                  ),
                ),
                if (!_loading)
                  GestureDetector(
                    onTap: _fetch,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.refresh,
                        size: 18,
                        color: nc.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedControl<String>(
              value: _mode,
              onChanged: (v) => setState(() => _mode = v),
              options: const [
                (value: 'auto', label: '自动选择'),
                (value: 'manual', label: '手动输入'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Flexible(
            child: _mode == 'auto' ? _buildAuto(nc) : _buildManual(nc),
          ),
        ],
      ),
    );
  }

  Widget _buildAuto(AgentColors nc) {
    if (_loading) return _ModelSkeletonList(nc: nc);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: TextStyle(fontSize: 13, color: nc.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _mode = 'manual'),
                child: Text(
                  '改用手动输入',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: nc.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_models.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '未获取到可用模型',
                style: TextStyle(fontSize: 13, color: nc.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _mode = 'manual'),
                child: Text(
                  '改用手动输入',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: nc.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        ..._models.map((m) {
          final sel = m == _current;
          return ListTile(
            title: Text(
              m,
              style: TextStyle(
                fontSize: 15,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                color: sel ? nc.success : nc.textPrimary,
              ),
            ),
            trailing: sel
                ? Icon(Icons.check_circle_outline, size: 20, color: nc.success)
                : null,
            onTap: () {
              HapticFeedback.lightImpact();
              widget.settings.setVendorModel(widget.vendor.id, m);
              widget.onChanged();
              Navigator.pop(context);
            },
          );
        }),
      ],
    );
  }

  Widget _buildManual(AgentColors nc) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '输入模型名称',
            style: TextStyle(fontSize: 13, color: nc.textSecondary),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: nc.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: nc.divider, width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _modelCtrl,
                    style: TextStyle(fontSize: 15, color: nc.textPrimary),
                    decoration: InputDecoration(
                      hintText: '例如: gpt-4o, claude-3-5-sonnet',
                      hintStyle: TextStyle(
                        color: nc.textSecondary.withValues(alpha: 0.6),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _useManual(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ElevatedButton(
                    onPressed: _modelCtrl.text.trim().isNotEmpty
                        ? _useManual
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: nc.primary,
                      foregroundColor: nc.surface,
                      disabledBackgroundColor: nc.fillTertiary,
                      disabledForegroundColor: nc.textDisabled,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 11,
                      ),
                    ),
                    child: Text(
                      '使用',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelSkeletonList extends StatefulWidget {
  final AgentColors nc;
  const _ModelSkeletonList({required this.nc});

  @override
  State<_ModelSkeletonList> createState() => _ModelSkeletonListState();
}

class _ModelSkeletonListState extends State<_ModelSkeletonList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.nc;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(5, (i) {
          final w = 0.4 + 0.35 * (i % 3) / 2;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Opacity(
              opacity: 0.25 + 0.15 * _ctrl.value,
              child: Container(
                width: MediaQuery.of(context).size.width * w,
                height: 14,
                decoration: BoxDecoration(
                  color: c.textSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
