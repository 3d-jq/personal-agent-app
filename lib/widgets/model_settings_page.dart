import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/agent_colors.dart';
import '../core/service_locator.dart';
import 'ai_settings_sheet.dart';

class ModelSettingsView extends StatefulWidget {
  const ModelSettingsView({super.key});
  @override
  State<ModelSettingsView> createState() => _ModelSettingsViewState();
}

class _ModelSettingsViewState extends State<ModelSettingsView> {
  final _aiSettings = getIt<AISettings>();
  bool _loaded = false;

  static const _thinkingOptions = [
    ('low', '低'),
    ('medium', '中'),
    ('high', '高'),
  ];

  String _thinkingLabel(String v) {
    return _thinkingOptions
        .firstWhere((o) => o.$1 == v, orElse: () => ('medium', '中'))
        .$2;
  }

  void _showThinkingPicker() {
    final nc = AgentColors.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 32),
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '思考强度',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: nc.textPrimary,
                ),
              ),
            ),
            Text(
              '控制模型推理深度，仅对支持推理的模型生效',
              style: TextStyle(fontSize: 13, color: nc.textSecondary),
            ),
            const SizedBox(height: 12),
            ..._thinkingOptions.map(
              (o) => ListTile(
                title: Text(
                  o.$2,
                  style: TextStyle(fontSize: 15, color: nc.textPrimary),
                ),
                subtitle: Text(
                  o.$1 == 'low'
                      ? '快速响应，适合简单任务'
                      : o.$1 == 'medium'
                      ? '平衡速度和深度（推荐）'
                      : '深度思考，适合复杂推理',
                  style: TextStyle(fontSize: 12, color: nc.textSecondary),
                ),
                trailing: _aiSettings.thinkingEffort == o.$1
                    ? Icon(PhosphorIconsRegular.check, color: nc.success)
                    : null,
                onTap: () {
                  setState(() => _aiSettings.thinkingEffort = o.$1);
                  _aiSettings.save();
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _aiSettings.load().then((_) => setState(() => _loaded = true));
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final vendor = _aiSettings.selectedVendor;

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIconsRegular.arrowLeft, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '模型',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: nc.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          _RoundedCard(
            nc: nc,
            children: [
              _SettingItem(
                icon: PhosphorIconsRegular.checkCircle,
                label: '推理模型',
                trailing: vendor?.name ?? '未配置',
                onTap: () {
                  HapticFeedback.lightImpact();
                  showBackendPicker(
                    context,
                    _aiSettings,
                    () => setState(() {}),
                  );
                },
              ),
              _SettingItem(
                icon: PhosphorIconsRegular.robot,
                label: '对话模型',
                trailing: vendor?.model.isNotEmpty == true
                    ? vendor!.model
                    : '未设置',
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (vendor != null)
                    showModelPicker(
                      context,
                      _aiSettings,
                      () => setState(() {}),
                    );
                },
              ),
              _SettingItem(
                icon: PhosphorIconsRegular.brain,
                label: '系统提示词',
                trailing: _thinkingLabel(_aiSettings.thinkingEffort),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showThinkingPicker();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: '管理', nc: nc),
          _RoundedCard(
            nc: nc,
            children: [
              _SettingItem(
                icon: PhosphorIconsRegular.slidersHorizontal,
                label: '管理厂商配置',
                onTap: () {
                  HapticFeedback.lightImpact();
                  showBackendPicker(
                    context,
                    _aiSettings,
                    () => setState(() {}),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (vendor != null) ...[
            _SectionHeader(title: '厂商信息', nc: nc),
            _RoundedCard(
              nc: nc,
              children: [
                _InfoRow(label: '名称', value: vendor.name, nc: nc),
                _InfoRow(label: 'Base URL', value: vendor.baseUrl, nc: nc),
                _InfoRow(
                  label: 'API Key',
                  value:
                      '${vendor.apiKey.substring(0, vendor.apiKey.length.clamp(0, 8))}...',
                  nc: nc,
                ),
              ],
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _RoundedCard extends StatelessWidget {
  final AgentColors nc;
  final List<Widget> children;
  const _RoundedCard({required this.nc, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nc.divider, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  const _SettingItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: nc.textPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: nc.textPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(fontSize: 15, color: nc.textSecondary),
                ),
              const SizedBox(width: 4),
              Icon(
                PhosphorIconsRegular.caretRight,
                size: 18,
                color: nc.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final AgentColors nc;
  const _SectionHeader({required this.title, required this.nc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: nc.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final AgentColors nc;
  const _InfoRow({required this.label, required this.value, required this.nc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: nc.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: nc.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
