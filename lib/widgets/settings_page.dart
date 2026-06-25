import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../core/app_router.dart';
import '../core/app_config.dart';
import '../core/service_locator.dart';
import '../services/theme_service.dart';
import '../services/update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    getIt<ThemeService>().addListener(_rebuild);
  }

  @override
  void dispose() {
    getIt<ThemeService>().removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _checkUpdate(BuildContext context, AgentColors nc) async {
    _showLoadingDialog(context, nc, '正在检查更新...');

    final current = AppConfig.version;
    UpdateInfo? info;
    try {
      info = await UpdateService.checkUpdate(current);
    } on UpdateException catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        _showResult(
          context,
          nc,
          '检查更新失败',
          e.reason.isEmpty ? '请稍后重试' : e.reason,
        );
      }
      return;
    }

    if (context.mounted) Navigator.pop(context);

    if (info == null) {
      if (context.mounted) {
        _showResult(context, nc, '已是最新版本', '当前 v$current');
      }
      return;
    }

    if (context.mounted) {
      _showUpdateDialog(context, nc, info);
    }
  }

  void _showResult(
    BuildContext context,
    AgentColors nc,
    String title,
    String msg,
  ) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: nc.surface,
        title: Text(title, style: TextStyle(color: nc.textPrimary)),
        content: Text(msg, style: TextStyle(color: nc.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog(
    BuildContext context,
    AgentColors nc,
    String message,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: nc.surface,
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(nc.textSecondary),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              message,
              style: TextStyle(color: nc.textPrimary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateDialog(
    BuildContext context,
    AgentColors nc,
    UpdateInfo info,
  ) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: nc.surface,
        title: Row(
          children: [
            Icon(Icons.system_update, color: nc.success, size: 24),
            const SizedBox(width: 8),
            Text(
              '发现新版本 v${info.version}',
              style: TextStyle(color: nc.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '当前版本：${AppConfig.displayVersion}',
                style: TextStyle(color: nc.textSecondary, fontSize: 13),
              ),
              if (info.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  info.notes,
                  style: TextStyle(color: nc.textPrimary, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('以后再说'),
          ),
          if (info.apkUrl != null)
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                _downloadAndInstall(context, nc, info.apkUrl!);
              },
              child: Text('立即更新', style: TextStyle(color: nc.success)),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('暂无安装包', style: TextStyle(color: nc.textSecondary)),
            ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(
    BuildContext context,
    AgentColors nc,
    String apkUrl,
  ) async {
    String? downloadPath;
    String downloadFailReason = '请检查网络后重试';

    // 下载进度（0.0 ~ 1.0）
    final progressNotifier = ValueNotifier<double?>(null); // null = 不确定模式

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => ValueListenableBuilder<double?>(
          valueListenable: progressNotifier,
          builder: (context, progress, _) {
            final done = progress != null && progress >= 1.0;
            return AlertDialog(
              backgroundColor: nc.surface,
              title: Text(
                done ? '下载完成' : '正在下载更新...',
                style: TextStyle(color: nc.textPrimary, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: done ? 1 : progress,
                    backgroundColor: nc.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(nc.success),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    done
                        ? '准备安装...'
                        : progress != null
                        ? '${(progress * 100).toStringAsFixed(0)}%'
                        : '正在连接...',
                    style: TextStyle(color: nc.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    try {
      downloadPath = await UpdateService.downloadApk(
        apkUrl,
        onProgress: (received, total) {
          progressNotifier.value = total > 0 ? received / total : null;
        },
      );
    } on UpdateException catch (e) {
      downloadFailReason = e.reason.isEmpty ? '请检查网络后重试' : e.reason;
    }

    progressNotifier.value = 1.0;
    progressNotifier.dispose();

    if (context.mounted) Navigator.pop(context);

    if (downloadPath == null) {
      if (context.mounted) {
        _showResult(context, nc, '下载失败', downloadFailReason);
      }
      return;
    }

    final apkPath = downloadPath; // 此处已确认非空，用于类型提升

    if (context.mounted) {
      _showLoadingDialog(context, nc, '正在安装...');
    }

    final success = await UpdateService.installApk(apkPath);

    if (context.mounted) Navigator.pop(context);

    if (!success && context.mounted) {
      _showResult(context, nc, '安装失败', '请手动安装或检查权限设置');
    }
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
        title: Text(
          '设置',
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
          _SectionHeader(title: '应用程序', nc: nc),
          _RoundedCard(
            nc: nc,
            children: [
              _SettingItem(
                icon: Icons.brightness_6_outlined,
                label: '主题',
                trailing: getIt<ThemeService>().label,
                onTap: () {
                  HapticFeedback.lightImpact();
                  final ts = getIt<ThemeService>();
                  final next = ts.mode == ThemeMode.light
                      ? ThemeMode.dark
                      : ts.mode == ThemeMode.dark
                      ? ThemeMode.system
                      : ThemeMode.light;
                  ts.setMode(next);
                },
              ),
              _ThemePicker(nc: nc),
              _BubbleColorPicker(nc: nc),
              _SettingItem(
                icon: Icons.layers_outlined,
                label: '模型',
                trailing: '管理',
                onTap: () {
                  HapticFeedback.lightImpact();
                  AppRouter.toModelSettings(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: '关于', nc: nc),
          _RoundedCard(
            nc: nc,
            children: [
              _SettingItem(
                label: '检查更新',
                trailing: AppConfig.displayVersion,
                onTap: () => _checkUpdate(context, nc),
              ),
              _SettingItem(
                label: '关于',
                onTap: () {
                  HapticFeedback.lightImpact();
                  AppRouter.toAbout(context);
                },
              ),
              _SettingItem(
                label: '致谢',
                onTap: () {
                  HapticFeedback.lightImpact();
                  AppRouter.toAcknowledgement(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 40),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
  const _SettingItem({
    this.icon,
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
              if (icon != null) ...[
                Icon(icon, size: 20, color: nc.textPrimary),
                const SizedBox(width: 14),
              ],
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
                  style: TextStyle(fontSize: 14, color: nc.textSecondary),
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

class _ThemePicker extends StatelessWidget {
  final AgentColors nc;
  const _ThemePicker({required this.nc});

  @override
  Widget build(BuildContext context) {
    final ts = getIt<ThemeService>();
    final currentKey = ts.themeKey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.palette_outlined, size: 20, color: nc.textPrimary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '主题',
              style: TextStyle(
                fontSize: 15,
                color: nc.textPrimary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          ...ts.themeKeys.map((key) {
            final isSelected = key == currentKey;
            final color = ts.themeColor(key);
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ts.setTheme(key);
              },
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? nc.primary : nc.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BubbleColorPicker extends StatelessWidget {
  final AgentColors nc;
  const _BubbleColorPicker({required this.nc});

  @override
  Widget build(BuildContext context) {
    final ts = getIt<ThemeService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentKey = ts.bubbleColorKey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.palette_outlined, size: 20, color: nc.textPrimary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '气泡',
              style: TextStyle(
                fontSize: 15,
                color: nc.textPrimary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          ...ThemeService.bubbleColors.entries.map((entry) {
            final isSelected = entry.key == currentKey;
            final colors = entry.value;
            final color = isDark ? colors.$2 : colors.$1;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ts.setBubbleColor(entry.key);
              },
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? nc.primary : nc.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 14, color: nc.primary)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}
