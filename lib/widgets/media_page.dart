import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import 'package:personal_agent_app/core/design_tokens.dart';
import 'common_widgets.dart';
import '../core/app_router.dart';
import '../models/media_item.dart';
import '../core/service_locator.dart';
import '../services/media_storage.dart';
import '../widgets/app_toast.dart';
import 'state_placeholder.dart';

class MediaView extends StatefulWidget {
  const MediaView({super.key});
  @override
  State<MediaView> createState() => _MediaViewState();
}

class _MediaViewState extends State<MediaView> {
  final _storage = getIt<MediaStorage>();
  List<MediaItem> _items = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _items = await _storage.loadAll();
    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppTopBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: nc.textPrimary, size: 22),
          onPressed: () => Navigator.pop(context),
          tooltip: '返回',
        ),
        title: '图视',
      ),
      body: !_loaded
          ? StatePlaceholder.loading()
          : _items.isEmpty
          ? StatePlaceholder.empty(
              icon: Icons.photo_library,
              title: '还没有图片和视频',
              subtitle: '在聊天中让 DWeis 帮你生成',
            )
          : GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: _items.length,
              itemBuilder: (_, i) => _mediaCard(_items[i], nc),
            ),
    );
  }

  Widget _mediaCard(MediaItem item, AgentColors nc) {
    final isVideo = item.type == MediaType.video;
    final file = File(item.filePath);

    return RepaintBoundary(
      child: PressableScale(
      onTap: () {
        HapticFeedback.lightImpact();
        AppRouter.push(context, _MediaDetail(item: item));
      },
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.lightImpact();
          _confirmDelete(item);
        },
        child: Container(
          decoration: BoxDecoration(
            color: nc.surface,
            borderRadius: BorderRadius.circular(RadiusToken.md),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!isVideo && file.existsSync())
                Image.file(
                  file,
                  fit: BoxFit.cover,
                  cacheWidth: 360,
                  cacheHeight: 360,
                  errorBuilder: (_, __, ___) => _placeholder(nc),
                )
              else
                _videoThumbnail(nc),
              if (isVideo)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xAA000000),
                      borderRadius: BorderRadius.circular(RadiusToken.sm),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          size: 12,
                          color: Colors.white,
                        ),
                        SizedBox(width: 2),
                        Text(
                          '视频',
                          style: TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _videoThumbnail(AgentColors nc) {
    return Container(
      color: nc.primarySurface,
      child: Center(
        child: Icon(
          Icons.videocam,
          size: 32,
          color: nc.textSecondary.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _placeholder(AgentColors nc) {
    return Container(
      color: nc.primarySurface,
      child: Center(
        child: Icon(
          Icons.image,
          size: 32,
          color: nc.textSecondary.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  void _confirmDelete(MediaItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除'),
        content: const Text('确定要删除这个媒体文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _storage.remove(item.id);
              _load();
            },
            child: Text('删除', style: TextStyle(color: AgentColors.of(ctx).error)),
          ),
        ],
      ),
    );
  }
}

class _MediaDetail extends StatelessWidget {
  final MediaItem item;
  const _MediaDetail({required this.item});

  Future<void> _launchSystemPlayer(BuildContext context, String filePath) async {
    final lower = filePath.toLowerCase();
    final mime = lower.endsWith('.mov')
        ? 'video/quicktime'
        : lower.endsWith('.webm')
            ? 'video/webm'
            : 'video/mp4';
    try {
      await const MethodChannel('com.example/open_file').invokeMethod(
        'openFile',
        {'path': filePath, 'mimeType': mime},
      );
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, '无法播放: $e', type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final file = File(item.filePath);
    final isVideo = item.type == MediaType.video;
    final exists = file.existsSync();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          item.prompt,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          if (isVideo && exists)
            IconButton(
              onPressed: () async {
                try {
                  final bytes = await file.readAsBytes();
                  await const MethodChannel(
                    'com.example/save_to_gallery',
                  ).invokeMethod('saveVideo', {
                    'bytes': bytes,
                    'name': 'dweis_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
                  });
                  if (context.mounted) {
                    AppToast.show(context, '已保存到相册', type: ToastType.success);
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppToast.show(context, '保存失败: $e', type: ToastType.error);
                  }
                }
              },
              icon: const Icon(Icons.download),
              tooltip: '保存',
            ),
        ],
      ),
      body: Center(
        child: !exists
            ? const Text('文件不存在', style: TextStyle(color: Colors.white54))
            : isVideo
                ? GestureDetector(
                    onTap: () => _launchSystemPlayer(context, item.filePath),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: nc.primarySurface,
                          borderRadius: BorderRadius.circular(RadiusToken.md),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  color: Color(0xAA000000),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '点击用系统播放器播放',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
      ),
    );
  }
}
