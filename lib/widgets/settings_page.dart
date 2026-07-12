import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../core/design_tokens.dart';
import '../core/app_router.dart';
import '../core/app_config.dart';
import '../core/service_locator.dart';
import '../services/log_service.dart';
import '../services/theme_service.dart';
import '../services/update_service.dart';
import 'common_widgets.dart';
import 'performance_page.dart';
import '../services/tts_service_config.dart';
import '../services/tts_provider.dart';

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

  /// 当前语音服务厂商的中文/品牌名（设置入口 trailing 展示）。
  String _speechLabel(TtsProviderType t) => switch (t) {
        TtsProviderType.system => '系统',
        TtsProviderType.openai => 'OpenAI',
        TtsProviderType.minimax => 'MiniMax',
        TtsProviderType.siliconflow => 'SiliconFlow',
        TtsProviderType.doubao => '豆包',
      };

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
        backgroundColor: nc.bgSubtle,
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
        backgroundColor: nc.bgSubtle,
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
            const SizedBox(width: SpaceToken.lg),
            Text(
              message,
              style: TextStyle(color: nc.textPrimary, fontSize: FontToken.small),
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
        backgroundColor: nc.bgSubtle,
        title: Row(
          children: [
            Icon(Icons.cloud_upload, color: nc.success, size: 24),
            const SizedBox(width: SpaceToken.sm),
            Text(
              '发现新版本 v${info.version}',
              style: TextStyle(color: nc.textPrimary, fontSize: FontToken.title),
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
                style: TextStyle(color: nc.textSecondary, fontSize: FontToken.small),
              ),
              if (info.notes.isNotEmpty) ...[
                const SizedBox(height: SpaceToken.md),
                Text(
                  info.notes,
                  style: TextStyle(color: nc.textPrimary, fontSize: FontToken.small),
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
              backgroundColor: nc.bgSubtle,
              title: Text(
                done ? '下载完成' : '正在下载更新...',
                style: TextStyle(color: nc.textPrimary, fontSize: FontToken.title),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: done ? 1 : progress,
                    backgroundColor: nc.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(nc.success),
                  ),
                  const SizedBox(height: SpaceToken.md),
                  Text(
                    done
                        ? '准备安装...'
                        : progress != null
                            ? '${(progress * 100).toStringAsFixed(0)}%'
                            : '正在连接...',
                    style: TextStyle(color: nc.textSecondary, fontSize: FontToken.small),
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
      backgroundColor: nc.bgSubtle,
      appBar: AppTopBar(
        title: '设置',
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
          SectionHeader(title: '应用程序', nc: nc),
          ElevatedCard(
            nc: nc,
            shadow: nc.shadowSm,
            child: Column(
              children: [
                _SettingItem(
                  icon: Icons.wb_sunny,
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
                Divider(height: 0.5, thickness: 0.5, color: nc.divider, indent: SpaceToken.lg, endIndent: SpaceToken.lg),
                _SettingItem(
                  icon: Icons.layers,
                  label: '模型',
                  trailing: '管理',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    AppRouter.toModelSettings(context);
                  },
                ),
                Divider(height: 0.5, thickness: 0.5, color: nc.divider, indent: SpaceToken.lg, endIndent: SpaceToken.lg),
                _SettingItem(
                  icon: Icons.delete,
                  label: '图片缓存',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    AppRouter.toImageCache(context);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: SpaceToken.xl),
          SectionHeader(title: '语音服务', nc: nc),
          ElevatedCard(
            nc: nc,
            shadow: nc.shadowSm,
            child: _SettingItem(
              icon: Icons.record_voice_over,
              label: '语音服务',
              trailing: _speechLabel(TtsServiceConfig.instance.type),
              onTap: () {
                HapticFeedback.lightImpact();
                AppRouter.toSpeechServices(context);
              },
            ),
          ),
          const SizedBox(height: SpaceToken.xl),
          SectionHeader(title: '调试', nc: nc),
          ElevatedCard(
            nc: nc,
            shadow: nc.shadowSm,
            child: SwitchListTile(
              title: Text('启用日志', style: TextStyle(fontSize: FontToken.body, color: nc.textPrimary)),
              subtitle: Text(
                '记录运行日志用于问题排查',
                style: TextStyle(fontSize: FontToken.small, color: nc.textSecondary),
              ),
              value: log.enabled,
              onChanged: (v) async {
                HapticFeedback.lightImpact();
                await log.setEnabled(v);
                setState(() {});
              },
              activeThumbColor: nc.primary,
            ),
          ),
          const SizedBox(height: SpaceToken.xl),
          SectionHeader(title: '关于', nc: nc),
          ElevatedCard(
            nc: nc,
            shadow: nc.shadowSm,
            child: Column(
              children: [
                _SettingItem(
                  icon: Icons.system_update,
                  label: '检查更新',
                  trailing: AppConfig.displayVersion,
                  onTap: () => _checkUpdate(context, nc),
                ),
                Divider(height: 0.5, thickness: 0.5, color: nc.divider, indent: SpaceToken.lg, endIndent: SpaceToken.lg),
                _SettingItem(
                  icon: Icons.article,
                  label: '运行日志',
                  trailing: log.enabled ? '已开启' : '已关闭',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    AppRouter.toLog(context);
                  },
                ),
                Divider(height: 0.5, thickness: 0.5, color: nc.divider, indent: SpaceToken.lg, endIndent: SpaceToken.lg),
                _SettingItem(
                  icon: Icons.analytics,
                  label: 'Token 消耗',
                  trailing: '按厂商/模型核算成本',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    AppRouter.toTokenUsage(context);
                  },
                ),
                Divider(height: 0.5, thickness: 0.5, color: nc.divider, indent: SpaceToken.lg, endIndent: SpaceToken.lg),
                _SettingItem(
                  icon: Icons.insights,
                  label: '性能',
                  trailing: '工具耗时 / 缓存命中 / 压缩',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, IosSlideRoute(page: const PerformancePage()));
                  },
                ),
                Divider(height: 0.5, thickness: 0.5, color: nc.divider, indent: SpaceToken.lg, endIndent: SpaceToken.lg),
                _SettingItem(
                  icon: Icons.info_outline,
                  label: '关于',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    AppRouter.toAbout(context);
                  },
                ),
                Divider(height: 0.5, thickness: 0.5, color: nc.divider, indent: SpaceToken.lg, endIndent: SpaceToken.lg),
                _SettingItem(
                  icon: Icons.favorite,
                  label: '致谢',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    AppRouter.toAcknowledgement(context);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: SpaceToken.x3),
        ],
      ),
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
      child: PressableScale(
        onTap: onTap ?? () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpaceToken.lg,
            vertical: SpaceToken.lg,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: nc.textPrimary),
                const SizedBox(width: SpaceToken.md),
              ],
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
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(fontSize: FontToken.body, color: nc.textSecondary),
                ),
              const SizedBox(width: SpaceToken.xs),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: nc.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
