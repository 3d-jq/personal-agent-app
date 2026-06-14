import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/agent_colors.dart';
import '../services/theme_service.dart';
import '../services/personalization_storage.dart';
import 'model_settings_page.dart';
import 'personalization_page.dart';
import 'about_page.dart';
import 'acknowledgement_view.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _personalization = PersonalizationStorage();

  @override
  void initState() {
    super.initState();
    ThemeService().addListener(_rebuild);
    _personalization.load().then((_) => setState(() {}));
  }
  @override void dispose() { ThemeService().removeListener(_rebuild); super.dispose(); }
  void _rebuild() => setState(() {});

  Future<void> _checkUpdate(BuildContext context, AgentColors nc) async {
    try {
      final dio = Dio();
      final resp = await dio.get(
        'https://api.github.com/repos/YOUR_USER/DWeis/releases/latest',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      if (resp.statusCode != 200) {
        _showResult(context, nc, '无法获取更新信息', '请稍后重试');
        return;
      }
      final tag = resp.data['tag_name'] as String? ?? '';
      final latest = tag.replaceFirst('v', '');
      const current = '0.6.0';
      final notes = resp.data['body'] as String? ?? '';
      final url = resp.data['html_url'] as String? ?? '';

      if (latest == current) {
        _showResult(context, nc, '已是最新版本', '当前 v$current');
      } else {
        _showUpdateDialog(context, nc, latest, notes, url);
      }
    } catch (_) {
      _showResult(context, nc, '检查更新失败', '请检查网络连接');
    }
  }

  void _showResult(BuildContext context, AgentColors nc, String title, String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: nc.surface,
        title: Text(title, style: TextStyle(color: nc.textPrimary)),
        content: Text(msg, style: TextStyle(color: nc.textSecondary)),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('确定'))],
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, AgentColors nc, String latest, String notes, String url) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: nc.surface,
        title: Row(
          children: [
            Icon(Icons.system_update, color: nc.success, size: 24),
            const SizedBox(width: 8),
            Text('发现新版本 v$latest', style: TextStyle(color: nc.textPrimary, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前版本：v0.6.0', style: TextStyle(color: nc.textSecondary, fontSize: 13)),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(notes, style: TextStyle(color: nc.textPrimary, fontSize: 13)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('以后再说')),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              if (url.isNotEmpty) launchUrl(Uri.parse(url));
            },
            child: Text('前往下载', style: TextStyle(color: nc.success)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: nc.textPrimary)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _UserCard(name: _personalization.userName, nc: nc),
          const SizedBox(height: 20),
          _SectionHeader(title: '应用程序', nc: nc),
          _RoundedCard(
            nc: nc,
            children: [
              _SettingItem(icon: Icons.brightness_6_outlined, label: '主题', trailing: ThemeService().label, onTap: () {
                HapticFeedback.lightImpact();
                final ts = ThemeService();
                final next = ts.mode == ThemeMode.light ? ThemeMode.dark : ts.mode == ThemeMode.dark ? ThemeMode.system : ThemeMode.light;
                ts.setMode(next);
              }),
              _SettingItem(icon: Icons.layers_outlined, label: '模型', trailing: '管理', onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ModelSettingsView()));
              }),
            _SettingItem(icon: Icons.tune_outlined, label: '个性化', trailing: _personalization.aiStyle, onTap: () async {
              HapticFeedback.lightImpact();
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalizationView()));
              await _personalization.load();
              setState(() {});
            }),
            ],
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: '关于', nc: nc),
          _RoundedCard(
            nc: nc,
            children: [
                _SettingItem(label: '检查更新', trailing: 'v0.6.0', onTap: () => _checkUpdate(context, nc)),
              _SettingItem(label: '关于', onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutView()));
              }),
              _SettingItem(label: '致谢', onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AcknowledgementView()));
              }),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String name;
  final AgentColors nc;
  const _UserCard({required this.name, required this.nc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: nc.textPrimary)),
          ),
        ],
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
      child: Text(title, style: TextStyle(fontSize: 13, color: nc.textSecondary, fontWeight: FontWeight.w500)),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 1))],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  const _SettingItem({this.icon, required this.label, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: nc.textPrimary),
                const SizedBox(width: 14),
              ],
              Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: nc.textPrimary, fontWeight: FontWeight.w400))),
              if (trailing != null) Text(trailing!, style: TextStyle(fontSize: 14, color: nc.textSecondary)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: nc.textSecondary.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
