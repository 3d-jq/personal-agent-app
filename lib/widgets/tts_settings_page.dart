import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../core/design_tokens.dart';
import '../services/tts_service.dart';
import '../services/tts_settings.dart';
import 'common_widgets.dart';
import 'app_toast.dart';

/// TTS 朗读语音设置页：在本机已有语音中选择，并一键跳转系统设置安装更多语言包。
class TtsSettingsPage extends StatefulWidget {
  const TtsSettingsPage({super.key});
  @override
  State<TtsSettingsPage> createState() => _TtsSettingsPageState();
}

class _TtsSettingsPageState extends State<TtsSettingsPage> {
  List<TtsVoice> _voices = [];
  bool _loading = true;
  Map<String, String>? _selected;

  @override
  void initState() {
    super.initState();
    _selected = TtsSettings().selectedVoice;
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    // 注意：HTTP 厂商（OpenAI 等）的 availableVoices 返回 const []（不可修改列表），
    // 直接 .sort() 会抛「Cannot modify an unmodifiable list」。先 .toList() 拷贝一份。
    final list = (await TtsService().availableVoices()).toList();
    if (!mounted) return;
    // 中文语音排前面，方便优先选择
    list.sort((a, b) {
      if (a.isChinese != b.isChinese) return a.isChinese ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    setState(() {
      _voices = list;
      _loading = false;
    });
  }

  Future<void> _pick(TtsVoice v) async {
    HapticFeedback.lightImpact();
    final voice = {'name': v.name, 'locale': v.locale};
    await TtsSettings().selectVoice(voice);
    TtsService().setSelectedVoice(voice);
    if (mounted) setState(() => _selected = voice);
  }

  Future<void> _clear() async {
    HapticFeedback.lightImpact();
    await TtsSettings().selectVoice(null);
    TtsService().setSelectedVoice(null);
    if (mounted) setState(() => _selected = null);
  }

  Future<void> _openSystem() async {
    HapticFeedback.lightImpact();
    final ok = await openSystemTtsSettings();
    if (!mounted) return;
    if (!ok) {
      AppToast.show(
        context,
        '无法打开系统语音设置，请手动前往：系统设置 → 文字转语音(TTS)输出',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Scaffold(
      backgroundColor: nc.bgSubtle,
      appBar: AppTopBar(
        title: '朗读语音',
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
          SectionHeader(title: '当前选择', nc: nc),
          ElevatedCard(
            nc: nc,
            child: Column(
              children: [
                _Row(
                  nc: nc,
                  label: _selected == null
                      ? '默认（跟随系统可用中文）'
                      : '${_selected!['name']}  ·  ${_selected!['locale']}',
                  onTap: _clear,
                  actionLabel: '清除',
                ),
              ],
            ),
          ),
          const SizedBox(height: SpaceToken.xl),
          SectionHeader(title: '可用语音', nc: nc),
          if (_loading)
            Padding(
              padding: const EdgeInsets.all(SpaceToken.lg),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(nc.textSecondary),
                  ),
                ),
              ),
            )
          else if (_voices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(SpaceToken.lg),
              child: Text(
                '未读到任何 TTS 语音。请点击下方按钮在系统设置中安装语音包。',
                style: TextStyle(color: nc.textSecondary, fontSize: FontToken.small),
              ),
            )
          else
            ElevatedCard(
              nc: nc,
              child: Column(
                children: [
                  for (var i = 0; i < _voices.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: nc.divider,
                        indent: SpaceToken.lg,
                        endIndent: 0,
                      ),
                    _VoiceTile(
                      nc: nc,
                      voice: _voices[i],
                      selected: _selected != null &&
                          _selected!['name'] == _voices[i].name &&
                          _selected!['locale'] == _voices[i].locale,
                      onTap: () => _pick(_voices[i]),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: SpaceToken.lg),
          ElevatedCard(
            nc: nc,
            child: _Row(
              nc: nc,
              label: '打开系统语音设置',
              sub: '在系统里安装 / 选择更多语言语音包',
              onTap: _openSystem,
              actionLabel: '前往',
              actionColor: nc.primary,
            ),
          ),
          const SizedBox(height: SpaceToken.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SpaceToken.lg),
            child: Text(
              '提示：Android 不允许 App 直接下载 TTS 语音数据，语音包由系统'
              '「文字转语音(TTS)输出」管理（如 Google 文字转语音引擎）。在此页'
              '选择本机已有语音，或点上方按钮去系统安装中文语音包。',
              style: TextStyle(color: nc.textDisabled, fontSize: FontToken.micro),
            ),
          ),
          const SizedBox(height: SpaceToken.x3),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final AgentColors nc;
  final String label;
  final String? sub;
  final VoidCallback onTap;
  final String actionLabel;
  final Color? actionColor;
  const _Row({
    required this.nc,
    required this.label,
    this.sub,
    required this.onTap,
    required this.actionLabel,
    this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: PressableScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpaceToken.lg, vertical: SpaceToken.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: FontToken.body, color: nc.textPrimary, fontWeight: WeightToken.medium)),
                    if (sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(sub!, style: TextStyle(fontSize: FontToken.small, color: nc.textSecondary)),
                      ),
                  ],
                ),
              ),
              Text(actionLabel, style: TextStyle(fontSize: FontToken.body, color: actionColor ?? nc.textSecondary)),
              const SizedBox(width: SpaceToken.xs),
              Icon(Icons.chevron_right, size: 18, color: nc.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceTile extends StatelessWidget {
  final AgentColors nc;
  final TtsVoice voice;
  final bool selected;
  final VoidCallback onTap;
  const _VoiceTile({
    required this.nc,
    required this.voice,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: PressableScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpaceToken.lg, vertical: SpaceToken.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voice.name,
                      style: TextStyle(
                        fontSize: FontToken.body,
                        color: nc.textPrimary,
                        fontWeight: selected ? WeightToken.semibold : WeightToken.medium,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      voice.locale,
                      style: TextStyle(fontSize: FontToken.small, color: nc.textSecondary),
                    ),
                  ],
                ),
              ),
              if (voice.isChinese)
                Container(
                  margin: const EdgeInsets.only(right: SpaceToken.sm),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: nc.primarySurface,
                    borderRadius: BorderRadius.circular(RadiusToken.xs),
                  ),
                  child: Text('中文', style: TextStyle(fontSize: FontToken.micro, color: nc.primary)),
                ),
              if (selected)
                Icon(Icons.check_circle, size: 20, color: nc.primary)
              else
                Icon(Icons.radio_button_off, size: 20, color: nc.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}
