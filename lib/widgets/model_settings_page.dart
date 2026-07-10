import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../core/design_tokens.dart';
import '../core/service_locator.dart';
import '../widgets/common_widgets.dart';
import 'ai_settings_sheet.dart';

class ModelSettingsView extends StatefulWidget {
  const ModelSettingsView({super.key});
  @override
  State<ModelSettingsView> createState() => _ModelSettingsViewState();
}

class _ModelSettingsViewState extends State<ModelSettingsView> {
  final _aiSettings = getIt<AISettings>();

  static const _thinkingOptions = [
    ('low', '低'),
    ('medium', '中'),
    ('high', '高'),
  ];

  static const _contextWindowOptions = [
    (32000, '32K'),
    (64000, '64K'),
    (128000, '128K'),
    (256000, '256K'),
    (512000, '512K'),
    (1000000, '1M'),
  ];

  String _thinkingLabel(String v) {
    return _thinkingOptions
        .firstWhere((o) => o.$1 == v, orElse: () => ('medium', '中'))
        .$2;
  }

  String _contextWindowLabel(int v) {
    return _contextWindowOptions
        .firstWhere((o) => o.$1 == v, orElse: () => (256000, '256K'))
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
                    ? Icon(Icons.check, color: nc.success)
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

  void _showContextWindowPicker() {
    final nc = AgentColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollController) => Padding(
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
                  '上下文窗口',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: nc.textPrimary,
                  ),
                ),
              ),
              Text(
                '设置模型的上下文窗口大小，占用约达 80% 时自动压缩（小窗口会预留输出空间，更早压缩）',
                style: TextStyle(fontSize: 13, color: nc.textSecondary),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ..._contextWindowOptions.map(
                      (o) => ListTile(
                        title: Text(
                          o.$2,
                          style: TextStyle(fontSize: 15, color: nc.textPrimary),
                        ),
                        subtitle: Text(
                          '${o.$1} tokens',
                          style: TextStyle(fontSize: 12, color: nc.textSecondary),
                        ),
                        trailing: _aiSettings.contextWindowSize == o.$1
                            ? Icon(Icons.check, color: nc.success)
                            : null,
                        onTap: () {
                          setState(() => _aiSettings.contextWindowSize = o.$1);
                          _aiSettings.save();
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                    // 自定义输入
                    ListTile(
                      title: Text(
                        '自定义',
                        style: TextStyle(fontSize: 15, color: nc.textPrimary),
                      ),
                      subtitle: Text(
                        '输入自定义 token 数',
                        style: TextStyle(fontSize: 12, color: nc.textSecondary),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCustomContextWindowDialog();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomContextWindowDialog() {
    final nc = AgentColors.of(context);
    final controller = TextEditingController(
      text: _aiSettings.contextWindowSize.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: nc.surface,
        title: Text(
          '自定义上下文窗口',
          style: TextStyle(fontSize: 16, color: nc.textPrimary),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '输入 token 数',
            hintStyle: TextStyle(color: nc.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          style: TextStyle(color: nc.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: nc.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                setState(() => _aiSettings.contextWindowSize = value);
                _aiSettings.save();
              }
              Navigator.pop(ctx);
            },
            child: Text('确定', style: TextStyle(color: nc.primary)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _aiSettings.load().then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final vendor = _aiSettings.selectedVendor;

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppTopBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: nc.textPrimary, size: 22),
          onPressed: () => Navigator.pop(context),
          tooltip: '返回',
        ),
        title: '模型',
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          SectionHeader(title: '对话设置', nc: nc),
          _RoundedCard(
            nc: nc,
            children: [
              _SettingItem(
                icon: Icons.check_circle_outline,
                label: 'AI 厂商',
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
                icon: Icons.smart_toy_outlined,
                label: '对话模型',
                trailing: vendor?.model.isNotEmpty == true
                    ? vendor!.model
                    : '未设置',
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (vendor != null) {
                    showModelPicker(
                      context,
                      _aiSettings,
                      () => setState(() {}),
                    );
                  }
                },
              ),
              _SettingItem(
                icon: Icons.psychology,
                label: '思考强度',
                trailing: _thinkingLabel(_aiSettings.thinkingEffort),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showThinkingPicker();
                },
              ),
              _SettingItem(
                icon: Icons.apps,
                label: '上下文窗口',
                trailing: _contextWindowLabel(_aiSettings.contextWindowSize),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showContextWindowPicker();
                },
              ),
            ],
          ),
          const SizedBox(height: SpaceToken.xl),
          if (vendor != null) ...[
            SectionHeader(title: '厂商信息', nc: nc),
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
    return ElevatedCard(nc: nc, child: Column(children: children));
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
        splashFactory: NoSplash.splashFactory,
        highlightColor: nc.fillTertiary,
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpaceToken.lg, vertical: SpaceToken.md),
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
                Icons.chevron_right,
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
