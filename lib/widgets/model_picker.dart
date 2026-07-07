import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/agent_colors.dart';
import '../services/ai_service.dart';
import 'ai_settings.dart';
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
  @override
  void initState() {
    super.initState();
    _fetch();
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
        providerName: widget.vendor.name,
        model: '',
      ).fetchModels();
      if (mounted)
        setState(() {
          _fetched = m;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
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
                        PhosphorIconsRegular.arrowsClockwise,
                        size: 18,
                        color: nc.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, color: nc.error),
              ),
            ),
          Flexible(
            child: _loading
                ? _ModelSkeletonList(nc: nc)
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ..._models.map((m) {
                        final sel = m == _current;
                        return ListTile(
                          title: Text(
                            m,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.w400,
                              color: sel ? nc.success : nc.textPrimary,
                            ),
                          ),
                          trailing: sel
                              ? Icon(PhosphorIconsRegular.checkCircle,
                                  size: 20, color: nc.success)
                              : null,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.settings
                                .setVendorModel(widget.vendor.id, m);
                            widget.onChanged();
                            Navigator.pop(context);
                          },
                        );
                      }),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _error!,
                            style: TextStyle(fontSize: 13, color: nc.error),
                            textAlign: TextAlign.center,
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