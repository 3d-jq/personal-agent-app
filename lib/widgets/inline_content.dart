import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../core/agent_colors.dart';
import '../core/app_animations.dart';

/// Build inline content: split text by markdown image patterns,
/// render text as MarkdownBody, and images as Image.network inline.
List<Widget> buildInlineContent(String text, AgentColors nc, BuildContext context) {
  final widgets = <Widget>[];
  final seenUrls = <String>{};
  final pattern = RegExp(r'!\[.*?\]\((https?://[^\s)]+|file://[^\s)]+)\)');
  var lastEnd = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > lastEnd) {
      final before = text.substring(lastEnd, match.start).trim();
      if (before.isNotEmpty) {
        widgets.add(mdBlock(before, nc, context));
      }
    }
    final url = match.group(1)!;
    if (seenUrls.add(url)) {
      widgets.add(_mediaWidget(url, nc, context));
    }
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    final after = text.substring(lastEnd).trim();
    if (after.isNotEmpty) {
      widgets.add(mdBlock(after, nc, context));
    }
  }
  return widgets;
}

Widget _mediaWidget(String url, AgentColors nc, BuildContext context) {
  final isLocal = url.startsWith('file://');
  final filePath = isLocal ? url.replaceFirst('file://', '') : url;
  final isVideo = filePath.endsWith('.mp4') || filePath.endsWith('.mov') || filePath.endsWith('.webm');
  final heroTag = 'ai_media_${url.hashCode}';

  if (isVideo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: PressableScale(
        onTap: () => Navigator.of(context).push(SlideFadeRoute(
          page: _FullscreenVideo(filePath: filePath, heroTag: heroTag),
        )),
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
                    width: 56, height: 56,
                    decoration: const BoxDecoration(color: Color(0xAA000000), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, size: 30, color: Colors.white),
                  ),
                  Positioned(
                    bottom: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(6)),
                      child: const Text('视频', style: TextStyle(fontSize: 11, color: Colors.white70)),
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
      onTap: () => Navigator.of(context).push(SlideFadeRoute(
        page: _FullscreenImage(url: url, heroTag: heroTag),
      )),
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isLocal
              ? Image.file(File(filePath), fit: BoxFit.contain, width: double.infinity,
                  errorBuilder: (ctx, err, stack) => Container(
                    height: 160, decoration: BoxDecoration(color: nc.primarySurface, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.broken_image_outlined, size: 32, color: nc.textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text('加载失败', style: TextStyle(fontSize: 12, color: nc.textSecondary)),
                    ])),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  memCacheWidth: 1080,
                  placeholder: (ctx, url) => Container(
                    height: 200,
                    decoration: BoxDecoration(color: nc.primarySurface, borderRadius: BorderRadius.circular(12)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.image_outlined, size: 28, color: nc.textSecondary.withValues(alpha: 0.25)),
                        const SizedBox(height: 6),
                        Text('加载中…', style: TextStyle(fontSize: 13, color: nc.textSecondary.withValues(alpha: 0.4), fontWeight: FontWeight.w500)),
                      ])),
                    ),
                  ),
                  errorWidget: (ctx, url, error) => Container(
                    height: 160,
                    decoration: BoxDecoration(color: nc.primarySurface, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.broken_image_outlined, size: 32, color: nc.textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text('加载失败', style: TextStyle(fontSize: 12, color: nc.textSecondary)),
                    ])),
                  ),
                ),
        ),
      ),
    ),
  );
}

Widget mdBlock(String text, AgentColors nc, [BuildContext? context]) {
  return MarkdownBody(
    data: text,
    selectable: true,
    styleSheet: MarkdownStyleSheet(
      p: TextStyle(fontSize: 15, color: nc.textPrimary, height: 1.6),
      h1: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: nc.textPrimary, height: 1.4),
      h2: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: nc.textPrimary, height: 1.4),
      h3: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: nc.textPrimary, height: 1.4),
      h4: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: nc.textPrimary, height: 1.4),
      h5: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: nc.textPrimary, height: 1.4),
      h6: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: nc.textPrimary, height: 1.4),
      a: TextStyle(fontSize: 15, color: nc.success, decoration: TextDecoration.underline),
      em: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: nc.textPrimary),
      strong: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: nc.textPrimary),
      code: TextStyle(fontSize: 13, color: const Color(0xFFEB5757), fontFamily: 'monospace'),
      codeblockDecoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10)),
      codeblockPadding: const EdgeInsets.all(14),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: nc.success, width: 3)),
        color: nc.success.withValues(alpha: 0.06),
      ),
      blockquotePadding: const EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 8),
      listBullet: TextStyle(fontSize: 15, color: nc.textPrimary),
      tableBorder: TableBorder.all(color: nc.divider),
      tableHead: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: nc.textPrimary),
      tableBody: TextStyle(fontSize: 14, color: nc.textPrimary),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: nc.divider, width: 0.5)),
      ),
    ),
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
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF333333), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: const Color(0xFF333333), width: 0.5)),
            ),
            child: Row(children: [
              Icon(Icons.code, size: 13, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                element.attributes['class']?.toString().replaceAll('language-', '') ?? 'code',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  HapticFeedback.lightImpact();
                  if (context != null) {
                    ScaffoldMessenger.of(context!).showSnackBar(
                      const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
                    );
                  }
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.copy, size: 13, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text('复制', style: TextStyle(fontSize: 11, color: Colors.white54)),
                ]),
              ),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: Text(code, style: const TextStyle(fontSize: 13, color: Color(0xFFD4D4D4), fontFamily: 'monospace', height: 1.5)),
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
        bytes = await File(widget.url.replaceFirst('file://', '')).readAsBytes();
      } else {
        final response = await Dio().get(widget.url, options: Options(responseType: ResponseType.bytes));
        bytes = response.data;
      }
      // Save to gallery
      await const MethodChannel('com.example/save_to_gallery').invokeMethod('saveImage', {
        'bytes': bytes,
        'name': 'agnes_${DateTime.now().millisecondsSinceEpoch}',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到相册')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildImage() {
    final isLocal = widget.url.startsWith('file://');
    if (isLocal) {
      return Image.file(File(widget.url.replaceFirst('file://', '')), fit: BoxFit.contain);
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.broken_image, size: 48, color: Colors.white38),
          SizedBox(height: 12),
          Text('加载失败', style: TextStyle(color: Colors.white38)),
        ]),
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
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded),
            tooltip: '保存',
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(child: Hero(tag: widget.heroTag, child: _buildImage())),
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
      await const MethodChannel('com.example/save_to_gallery').invokeMethod('saveVideo', {
        'bytes': bytes,
        'name': 'dweis_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到相册')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
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
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_outlined, size: 64, color: Colors.white38),
                    const SizedBox(height: 16),
                    Text('视频文件', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      widget.filePath.split(Platform.pathSeparator).last,
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: GestureDetector(
                onTap: () async {
                  try {
                    await MethodChannel('com.example/open_file').invokeMethod('openFile', {'path': widget.filePath});
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('无法播放: $e\n请安装视频播放器应用')),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text('用播放器打开', style: TextStyle(color: Colors.white, fontSize: 15)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
