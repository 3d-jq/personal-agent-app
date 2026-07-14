import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import '../core/agent_colors.dart';
import '../core/app_router.dart';
import '../core/design_tokens.dart';
import '../widgets/app_toast.dart';

/// 调用原生「用系统播放器打开」能力（com.example/open_file → openFile）。
const _kOpenFileChannel = MethodChannel('com.example/open_file');

/// 对话框内联图片（截图 / 生成图）的最大显示高度；点开仍走全屏大图。
const double _kMaxInlineImageHeight = 260;

/// 按扩展名推断视频 MIME，保证 .mov/.webm/.mkv 也能被系统播放器识别。
String _videoMimeType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.mkv')) return 'video/x-matroska';
  return 'video/mp4';
}

/// 直接调起手机系统视频播放器。失败时回退到应用内 _FullscreenVideo 以便保存/重试。
Future<void> _launchSystemPlayer(
  BuildContext context,
  String filePath,
  String heroTag,
) async {
  try {
    await _kOpenFileChannel.invokeMethod('openFile', {
      'path': filePath,
      'mimeType': _videoMimeType(filePath),
    });
  } catch (e) {
    if (context.mounted) {
      AppToast.show(context, '无法打开系统播放器', type: ToastType.error);
      AppRouter.push(context, _FullscreenVideo(filePath: filePath, heroTag: heroTag));
    }
  }
}

/// Build inline content: split text by markdown image patterns,
/// render text as MarkdownBody, and images as Image.network inline.
List<Widget> buildInlineContent(
  String text,
  AgentColors nc,
  BuildContext context,
) {
  final mq = MediaQuery.of(context);
  final maxImagePixels = (mq.size.width * mq.devicePixelRatio).round();
  final widgets = <Widget>[];
  final seenUrls = <String>{};
  final pattern = RegExp(r'!\[.*?\]\((https?://[^\s)]+|file://[^\s)]+)\)');
  var lastEnd = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > lastEnd) {
      final before = text.substring(lastEnd, match.start).trim();
      if (before.isNotEmpty) {
        widgets.add(RepaintBoundary(child: mdBlock(before, nc, context)));
      }
    }
    final url = match.group(1)!;
    if (seenUrls.add(url)) {
      widgets.add(RepaintBoundary(child: _mediaWidget(url, nc, context, maxImagePixels)));
    }
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    final after = text.substring(lastEnd).trim();
    if (after.isNotEmpty) {
      widgets.add(RepaintBoundary(child: mdBlock(after, nc, context)));
    }
  }
  return widgets;
}

Widget _mediaWidget(String url, AgentColors nc, BuildContext context, int maxCacheWidth) {
  final isLocal = url.startsWith('file://');
  final filePath = isLocal ? url.replaceFirst('file://', '') : url;
  final isVideo =
      filePath.endsWith('.mp4') ||
      filePath.endsWith('.mov') ||
      filePath.endsWith('.webm');
  final heroTag = 'ai_media_${url.hashCode}';

  if (isVideo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: PressableScale(
        onTap: () => _launchSystemPlayer(context, filePath, heroTag),
        child: Hero(
          tag: heroTag,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: nc.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xAA000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xAA000000),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '视频',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: PressableScale(
      onTap: () =>
          AppRouter.push(context, _FullscreenImage(url: url, heroTag: heroTag)),
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(RadiusToken.md),
          child: isLocal
              ? Image.file(
                  File(filePath),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: _kMaxInlineImageHeight,
                  cacheWidth: maxCacheWidth,
                  errorBuilder: (ctx, err, stack) => Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: nc.primarySurface,
                      borderRadius: BorderRadius.circular(RadiusToken.md),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 32,
                            color: nc.textSecondary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '加载失败',
                            style: TextStyle(
                              fontSize: 12,
                              color: nc.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: _kMaxInlineImageHeight,
                  memCacheWidth: maxCacheWidth,
                  placeholder: (ctx, url) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: nc.primarySurface,
                      borderRadius: BorderRadius.circular(RadiusToken.md),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.image,
                              size: 28,
                              color: nc.textSecondary.withValues(alpha: 0.25),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '加载中…',
                              style: TextStyle(
                                fontSize: 13,
                                color: nc.textSecondary.withValues(alpha: 0.4),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (ctx, url, error) => Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: nc.primarySurface,
                      borderRadius: BorderRadius.circular(RadiusToken.md),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 32,
                            color: nc.textSecondary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '加载失败',
                            style: TextStyle(
                              fontSize: 12,
                              color: nc.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    ),
  );
}

/// 缓存的 MarkdownStyleSheet（按主题颜色哈希，避免每次渲染重新构建）
MarkdownStyleSheet? _cachedMdStyle;
int _cachedMdStyleHash = 0;

MarkdownStyleSheet _mdStyleSheet(AgentColors nc) {
  final hash = Object.hash(
    nc.textPrimary,
    nc.textSecondary,
    nc.primary,
    nc.divider,
    nc.primarySurface,
    nc.success,
  );
  if (_cachedMdStyle != null && _cachedMdStyleHash == hash) {
    return _cachedMdStyle!;
  }
  _cachedMdStyleHash = hash;
  return _cachedMdStyle = MarkdownStyleSheet(
    p: TextStyle(fontSize: 16, color: nc.textPrimary, height: 1.6),
    h1: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: nc.textPrimary,
      height: 1.4,
    ),
    h2: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: nc.textPrimary,
      height: 1.4,
    ),
    h3: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: nc.textPrimary,
      height: 1.4,
    ),
    h4: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: nc.textPrimary,
      height: 1.4,
    ),
    h5: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: nc.textPrimary,
      height: 1.4,
    ),
    h6: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: nc.textPrimary,
      height: 1.4,
    ),
    a: TextStyle(
      fontSize: 16,
      color: nc.primary,
      decoration: TextDecoration.underline,
      decorationColor: nc.primary,
    ),
    em: TextStyle(
      fontSize: 16,
      fontStyle: FontStyle.italic,
      color: nc.textPrimary,
    ),
    strong: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: nc.textPrimary,
    ),
    code: TextStyle(
      fontSize: 14,
      color: nc.textPrimary,
      backgroundColor: nc.divider.withValues(alpha: 0.5),
      fontFamily: 'monospace',
    ),
    codeblockDecoration: BoxDecoration(
      color: nc.primarySurface,
      border: Border.all(color: nc.divider, width: 0.5),
      borderRadius: BorderRadius.circular(12),
    ),
    codeblockPadding: const EdgeInsets.all(14),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: nc.success, width: 3)),
      color: nc.success.withValues(alpha: 0.06),
    ),
    blockquotePadding: const EdgeInsets.only(
      left: 14,
      right: 14,
      top: 8,
      bottom: 8,
    ),
    listBullet: TextStyle(fontSize: 16, color: nc.textPrimary),
    tableBorder: TableBorder.all(color: nc.divider),
    tableHead: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: nc.textPrimary,
    ),
    tableBody: TextStyle(fontSize: 16, color: nc.textPrimary),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: nc.divider, width: 0.5)),
    ),
  );
}

Widget mdBlock(String text, AgentColors nc, [BuildContext? context]) {
  return MarkdownBody(
    data: text,
    onTapLink: (text, href, title) async {
      if (href == null || href.isEmpty) return;
      final uri = Uri.tryParse(href);
      if (uri == null) return;
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // 链接无法在当前环境打开时静默失败，避免抛异常中断 UI
      }
    },
    styleSheet: _mdStyleSheet(nc),
    builders: {'code': CodeBlockBuilder(nc: nc, context: context)},
  );
}

/// Renders code blocks with a copy button.
class CodeBlockBuilder extends MarkdownElementBuilder {
  final AgentColors nc;
  final BuildContext? context;
  CodeBlockBuilder({required this.nc, this.context});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'code') return null;
    final code = element.textContent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: nc.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nc.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: nc.divider, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.code, size: 13, color: nc.textSecondary),
                const SizedBox(width: 6),
                Text(
                  element.attributes['class']?.toString().replaceAll(
                        'language-',
                        '',
                      ) ??
                      'code',
                  style: TextStyle(fontSize: 11, color: nc.textSecondary),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    HapticFeedback.lightImpact();
                    if (context != null) {
                      AppToast.show(context!, '已复制到剪贴板');
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_copy, size: 13, color: nc.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '复制',
                        style: TextStyle(fontSize: 11, color: nc.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: Text(
              code,
              style: TextStyle(
                fontSize: 13,
                color: nc.textPrimary,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fullscreen image viewer ──

class _FullscreenImage extends StatefulWidget {
  final String url;
  final String heroTag;
  const _FullscreenImage({required this.url, required this.heroTag});

  @override
  State<_FullscreenImage> createState() => _FullscreenImageState();
}

class _FullscreenImageState extends State<_FullscreenImage> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      Uint8List bytes;
      if (widget.url.startsWith('file://')) {
        bytes = await File(
          widget.url.replaceFirst('file://', ''),
        ).readAsBytes();
      } else {
        final response = await Dio().get(
          widget.url,
          options: Options(responseType: ResponseType.bytes),
        );
        bytes = response.data;
      }
      // Save to gallery
      await const MethodChannel('com.example/save_to_gallery').invokeMethod(
        'saveImage',
        {
          'bytes': bytes,
          'name': 'agnes_${DateTime.now().millisecondsSinceEpoch}',
        },
      );
      if (mounted) {
        AppToast.show(context, '已保存到相册', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, '保存失败: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildImage() {
    final isLocal = widget.url.startsWith('file://');
    if (isLocal) {
      return Image.file(
        File(widget.url.replaceFirst('file://', '')),
        fit: BoxFit.contain,
      );
    }
    return Image.network(
      widget.url,
      fit: BoxFit.contain,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            color: Colors.white70,
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (ctx, err, stack) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, size: 48, color: Colors.white38),
            SizedBox(height: 12),
            Text('加载失败', style: TextStyle(color: Colors.white38)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            tooltip: '保存',
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Hero(tag: widget.heroTag, child: _buildImage()),
        ),
      ),
    );
  }
}

// ── Fullscreen video viewer ──

class _FullscreenVideo extends StatefulWidget {
  final String filePath;
  final String heroTag;
  const _FullscreenVideo({required this.filePath, required this.heroTag});

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      await const MethodChannel(
        'com.example/save_to_gallery',
      ).invokeMethod('saveVideo', {
        'bytes': bytes,
        'name': 'dweis_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      });
      if (mounted) {
        AppToast.show(context, '已保存到相册', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, '保存失败: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            tooltip: '保存',
          ),
        ],
      ),
      body: Hero(
        tag: widget.heroTag,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: () => _launchSystemPlayer(
                    context,
                    widget.filePath,
                    widget.heroTag,
                  ),
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
                      const SizedBox(height: 16),
                      const Text(
                        '点击用系统播放器播放',
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.filePath.split(Platform.pathSeparator).last,
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: GestureDetector(
                onTap: () async {
                  try {
                    await _kOpenFileChannel.invokeMethod('openFile', {
                      'path': widget.filePath,
                      'mimeType': _videoMimeType(widget.filePath),
                    });
                  } catch (e) {
                    if (mounted) {
                      AppToast.show(context, '无法播放: $e', type: ToastType.error);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '用播放器打开',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
