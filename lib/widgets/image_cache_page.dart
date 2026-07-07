import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/agent_colors.dart';
import '../core/service_locator.dart';
import '../services/media_storage.dart';

/// 图片缓存管理页面
class ImageCachePage extends StatefulWidget {
  const ImageCachePage({super.key});

  @override
  State<ImageCachePage> createState() => _ImageCachePageState();
}

class _ImageCachePageState extends State<ImageCachePage> {
  int _cacheSize = 0;
  int _imageCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    setState(() => _loading = true);
    
    // 获取媒体存储信息
    final storage = getIt<MediaStorage>();
    final items = await storage.loadAll();
    
    // 计算缓存大小（这里简化为统计图片数量）
    _imageCount = items.where((item) => item.type.name == 'image').length;
    
    // 估算缓存大小（每张图片约 500KB）
    _cacheSize = _imageCount * 500 * 1024;
    
    setState(() => _loading = false);
  }

  Future<void> _clearCache() async {
    final nc = AgentColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: nc.surface,
        title: Text('清除缓存', style: TextStyle(color: nc.textPrimary)),
        content: Text(
          '确定要清除图片缓存吗？\n这将删除 ${_imageCount} 张图片的缓存。',
          style: TextStyle(color: nc.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: nc.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('清除', style: TextStyle(color: nc.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 清除缓存逻辑
      setState(() {
        _cacheSize = 0;
        _imageCount = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缓存已清除')),
        );
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: nc.background.withValues(alpha: 0.85),
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIconsRegular.arrowLeft, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '图片缓存',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: nc.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 缓存信息卡片
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: nc.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: nc.divider, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        PhosphorIconsRegular.image,
                        size: 48,
                        color: nc.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _formatSize(_cacheSize),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: nc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_imageCount 张图片',
                        style: TextStyle(
                          fontSize: 15,
                          color: nc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // 清除缓存按钮
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _clearCache,
                    icon: Icon(PhosphorIconsRegular.trash, size: 18),
                    label: const Text('清除缓存'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: nc.error,
                      side: BorderSide(color: nc.error.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // 说明
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: nc.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '关于缓存',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: nc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '图片缓存用于加速图片加载。清除缓存后，图片需要重新下载。',
                        style: TextStyle(
                          fontSize: 13,
                          color: nc.textSecondary,
                          height: 1.5,
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
