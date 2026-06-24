import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../core/app_animations.dart';
import '../core/app_router.dart';
import '../models/media_item.dart';
import '../core/service_locator.dart';
import '../services/media_storage.dart';

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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('图视',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: nc.textPrimary)),
        centerTitle: true,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _emptyState(nc)
              : GridView.builder(
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

  Widget _emptyState(AgentColors nc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined, size: 48, color: nc.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('还没有图片和视频',
              style: TextStyle(fontSize: 15, color: nc.textSecondary.withValues(alpha: 0.6))),
          const SizedBox(height: 6),
          Text('在聊天中让 DWeis 帮你生成',
              style: TextStyle(fontSize: 13, color: nc.textSecondary.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _mediaCard(MediaItem item, AgentColors nc) {
    final isVideo = item.type == MediaType.video;
    final file = File(item.filePath);

    return PressableScale(
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 1))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!isVideo && file.existsSync())
              Image.file(file, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(nc))
            else
              _videoThumbnail(nc),
            if (isVideo)
              Positioned(
                bottom: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xAA000000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white),
                    SizedBox(width: 2),
                    Text('视频', style: TextStyle(fontSize: 10, color: Colors.white70)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _videoThumbnail(AgentColors nc) {
    return Container(
      color: nc.primarySurface,
      child: Center(
        child: Icon(Icons.videocam_outlined, size: 32, color: nc.textSecondary.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _placeholder(AgentColors nc) {
    return Container(
      color: nc.primarySurface,
      child: Center(
        child: Icon(Icons.image_outlined, size: 32, color: nc.textSecondary.withValues(alpha: 0.3)),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _storage.remove(item.id);
              _load();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _MediaDetail extends StatelessWidget {
  final MediaItem item;
  const _MediaDetail({required this.item});

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final file = File(item.filePath);
    final isVideo = item.type == MediaType.video;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(item.prompt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14)),
      ),
      body: Center(
        child: file.existsSync()
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: isVideo
                    ? AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: nc.primarySurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_outline_rounded, size: 64, color: nc.textSecondary.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text('视频文件', style: TextStyle(color: nc.textSecondary, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Image.file(file, fit: BoxFit.contain),
              )
            : const Text('文件不存在', style: TextStyle(color: Colors.white54)),
      ),
    );
  }
}
