import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../core/design_tokens.dart';
import '../core/app_router.dart';
import '../services/tts_service.dart';
import '../services/tts_service_config.dart';
import '../services/tts_provider.dart';
import '../services/tts_settings.dart';
import 'common_widgets.dart';
import 'app_toast.dart';
import 'tts_settings_page.dart';

/// 语音服务设置（借鉴 Operit SpeechServicesSettingsScreen）。
///
/// 顶部按厂商选择（系统 / OpenAI / MiniMax / SiliconFlow / 豆包）；
/// 系统 TTS 走设备语音（链接到原「朗读语音」选择 + 语速/音调）；
/// HTTP 类厂商配置 Base URL / API Key / 模型 / Voice ID + 语速/音调；
/// 底部「试听」用当前配置合成一段示例，「保存」持久化并接线工厂。
class SpeechServicesSettingsPage extends StatefulWidget {
  const SpeechServicesSettingsPage({super.key});

  @override
  State<SpeechServicesSettingsPage> createState() =>
      _SpeechServicesSettingsPageState();
}

class _SpeechServicesSettingsPageState
    extends State<SpeechServicesSettingsPage> {
  final _cfg = TtsServiceConfig.instance;
  final _tts = TtsService();

  late final TextEditingController _baseUrlC;
  late final TextEditingController _apiKeyC;
  late final TextEditingController _modelC;
  late final TextEditingController _voiceIdC;

  bool _speaking = false;

  static const _sample = '这是一段语音合成测试，用于试听当前语音服务配置。';

  @override
  void initState() {
    super.initState();
    _baseUrlC = TextEditingController(text: _cfg.baseUrl);
    _apiKeyC = TextEditingController(text: _cfg.apiKey);
    _modelC = TextEditingController(text: _cfg.model);
    _voiceIdC = TextEditingController(text: _cfg.voiceId);
    _tts.speakingChanges.listen((v) {
      if (mounted) setState(() => _speaking = v);
    });
  }

  @override
  void dispose() {
    _baseUrlC.dispose();
    _apiKeyC.dispose();
    _modelC.dispose();
    _voiceIdC.dispose();
    super.dispose();
  }

  Future<void> _onPickType(TtsProviderType t) async {
    if (t == _cfg.type) return;
    HapticFeedback.lightImpact();
    _cfg.selectType(t); // 同步切工厂 + UI 状态（即时反馈）
    if (mounted) setState(() {});
    unawaited(_cfg.setType(t)); // 后台持久化（wire 幂等已切过）
  }

  Future<void> _save() async {
    _cfg.baseUrl = _baseUrlC.text.trim();
    _cfg.apiKey = _apiKeyC.text.trim();
    _cfg.model = _modelC.text.trim();
    _cfg.voiceId = _voiceIdC.text.trim();
    await _cfg.apply();
    if (mounted) {
      AppToast.show(context, '已保存语音服务配置', type: ToastType.success);
    }
  }

  Future<void> _preview() async {
    // 保存最新配置并接线，确保试听用当前参数。
    await _save();
    final res = await _tts.speak(_sample);
    if (mounted && res.warning != null) {
      AppToast.show(context, res.warning!, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final isHttp = _cfg.type != TtsProviderType.system;
    return Scaffold(
      backgroundColor: nc.bgSubtle,
      appBar: AppTopBar(
        title: '语音服务',
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: SpaceToken.lg),
        children: [
          const SizedBox(height: SpaceToken.sm),
          SectionHeader(title: '厂商', nc: nc),
          _VendorSegmented(
            selected: _cfg.type,
            onPick: _onPickType,
            nc: nc,
          ),
          const SizedBox(height: SpaceToken.xl),
          if (isHttp) _httpConfigCard(nc: nc),
          if (!isHttp) _systemConfigCard(nc: nc),
          const SizedBox(height: SpaceToken.xl),
          _ratePitchCard(nc: nc),
          const SizedBox(height: SpaceToken.x3),
        ],
      ),
      bottomNavigationBar: _speaking
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(SpaceToken.lg),
                child: FilledButton.icon(
                  onPressed: () => _tts.stop(),
                  icon: const Icon(Icons.stop),
                  label: const Text('停止朗读'),
                ),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(SpaceToken.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存配置'),
                      ),
                    ),
                    const SizedBox(width: SpaceToken.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _preview,
                        icon: const Icon(Icons.volume_up),
                        label: const Text('试听'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _httpConfigCard({required AgentColors nc}) => ElevatedCard(
        nc: nc,
        shadow: nc.shadowSm,
        child: Padding(
          padding: const EdgeInsets.all(SpaceToken.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Field(label: 'Base URL', hint: 'https://api.openai.com/v1', controller: _baseUrlC),
              _Field(label: 'API Key', hint: 'sk-...', controller: _apiKeyC, obscure: true),
              _Field(label: '模型', hint: 'gpt-4o-mini-tts / 等', controller: _modelC),
              _Field(label: 'Voice ID', hint: '留空用厂商默认（如 alloy）', controller: _voiceIdC),
            ],
          ),
        ),
      );

  Widget _systemConfigCard({required AgentColors nc}) => ElevatedCard(
        nc: nc,
        shadow: nc.shadowSm,
        child: Column(
          children: [
            _SettingRow(
              icon: Icons.record_voice_over,
              label: '朗读语音',
              trailing: TtsSettings().selectedVoiceName ?? '默认',
              onTap: () {
                HapticFeedback.lightImpact();
                AppRouter.push(context, const TtsSettingsPage());
              },
            ),
            Divider(height: 0.5, thickness: 0.5, color: nc.divider, indent: SpaceToken.lg, endIndent: SpaceToken.lg),
            _SettingRow(
              icon: Icons.settings_voice,
              label: '安装语音包',
              trailing: '系统设置',
              onTap: () async {
                HapticFeedback.lightImpact();
                await openSystemTtsSettings();
              },
            ),
          ],
        ),
      );

  Widget _ratePitchCard({required AgentColors nc}) => ElevatedCard(
        nc: nc,
        shadow: nc.shadowSm,
        child: Padding(
          padding: const EdgeInsets.all(SpaceToken.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SliderRow(
                label: '语速',
                value: _cfg.rate,
                onChanged: (v) {
                  _cfg.rate = v;
                  _tts.setRate(v);
                  setState(() {});
                },
              ),
              const SizedBox(height: SpaceToken.md),
              _SliderRow(
                label: '音调',
                value: _cfg.pitch,
                onChanged: (v) {
                  _cfg.pitch = v;
                  _tts.setPitch(v);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
  });
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SpaceToken.md),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(color: nc.textPrimary, fontSize: FontToken.body),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: nc.textDisabled, fontSize: FontToken.small),
          labelStyle: TextStyle(color: nc.textSecondary, fontSize: FontToken.small),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: nc.divider),
          ),
          enabledBorder: OutlineInputBorder(
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
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpaceToken.lg,
            vertical: SpaceToken.lg,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: nc.textPrimary),
              const SizedBox(width: SpaceToken.md),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: FontToken.body,
                    color: nc.textPrimary,
                    fontWeight: WeightToken.medium,
                  ),
                ),
              ),
              Text(trailing, style: TextStyle(fontSize: FontToken.body, color: nc.textSecondary)),
              const SizedBox(width: SpaceToken.xs),
              Icon(Icons.chevron_right, size: 18, color: nc.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(label, style: TextStyle(fontSize: FontToken.small, color: nc.textSecondary)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            activeColor: nc.primary,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: FontToken.small, color: nc.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// 等宽厂商分段选择：每个厂商占 1/5 宽度（Expanded），名字过长自动缩放，
/// 避免 SegmentedButton 按文字长度分配宽度导致的「长短不一 / 被撑大」。
class _VendorSegmented extends StatelessWidget {
  final TtsProviderType selected;
  final ValueChanged<TtsProviderType> onPick;
  final AgentColors nc;

  const _VendorSegmented({
    required this.selected,
    required this.onPick,
    required this.nc,
  });

  static const _items = [
    (TtsProviderType.system, '系统'),
    (TtsProviderType.openai, 'OpenAI'),
    (TtsProviderType.minimax, 'MiniMax'),
    (TtsProviderType.siliconflow, 'SiliconFlow'),
    (TtsProviderType.doubao, '豆包'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final (type, label) in _items)
            Expanded(
              child: _VendorSegment(
                label: label,
                selected: selected == type,
                onTap: () => onPick(type),
                nc: nc,
              ),
            ),
        ],
      ),
    );
  }
}

class _VendorSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AgentColors nc;

  const _VendorSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.nc,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? nc.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: FontToken.small,
                fontWeight: WeightToken.medium,
                color: selected ? nc.onPrimary : nc.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
