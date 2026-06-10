import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path_provider/path_provider.dart';
import '../core/agent_colors.dart';

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
        widgets.add(mdBlock(before, nc));
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
      widgets.add(mdBlock(after, nc));
    }
  }
  return widgets;
}

Widget _mediaWidget(String url, AgentColors nc, BuildContext context) {
  final isLocal = url.startsWith('file://');
  final filePath = isLocal ? url.replaceFirst('file://', '') : url;
  final isVideo = filePath.endsWith('.mp4') || filePath.endsWith('.mov') || filePath.endsWith('.webm');

  if (isVideo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () => _openVideo(filePath),
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
                if (isLocal && File(filePath).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(filePath), fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
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
    );
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _FullscreenImage(url: url)),
      ),
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
            : Image.network(url, fit: BoxFit.contain, width: double.infinity,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  final pct = (progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)).clamp(0.0, 1.0);
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(color: nc.primarySurface, borderRadius: BorderRadius.circular(12)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(children: [
                        Positioned(top: 0, left: 0, right: 0, height: 200 * pct,
                          child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [nc.divider.withValues(alpha: 0.4), nc.divider.withValues(alpha: 0.15)],
                          ))),
                        ),
                        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.image_outlined, size: 28, color: nc.textSecondary.withValues(alpha: 0.25)),
                          const SizedBox(height: 6),
                          Text('${(pct * 100).toInt()}%', style: TextStyle(fontSize: 13, color: nc.textSecondary.withValues(alpha: 0.4), fontWeight: FontWeight.w500)),
                        ])),
                      ]),
                    ),
                  );
                },
                errorBuilder: (ctx, err, stack) => Container(
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
  );
}

Future<void> _openVideo(String filePath) async {
  try {
    await const MethodChannel('com.example/open_file').invokeMethod('openFile', {'path': filePath});
  } catch (_) {}
}

Widget mdBlock(String text, AgentColors nc) {
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
      a: const TextStyle(fontSize: 15, color: Color(0xFF0F7B6C), decoration: TextDecoration.underline),
      em: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: nc.textPrimary),
      strong: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: nc.textPrimary),
      code: TextStyle(fontSize: 13, color: const Color(0xFFEB5757), backgroundColor: nc.surface, fontFamily: 'monospace'),
      codeblockDecoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10)),
      codeblockPadding: const EdgeInsets.all(14),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: const Color(0xFF0F7B6C), width: 3)),
        color: const Color(0xFF0F7B6C).withValues(alpha: 0.06),
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
    builders: {'code': CodeBlockBuilder(nc: nc)},
  );
}

/// Renders code blocks with a copy button.
class CodeBlockBuilder extends MarkdownElementBuilder {
  final AgentColors nc;
  CodeBlockBuilder({required this.nc});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'code') return null;
    final code = element.textContent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF333333), width: 0.5)),
            ),
            child: Row(children: [
              Icon(Icons.code, size: 13, color: nc.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                element.attributes['class']?.toString().replaceAll('language-', '') ?? 'code',
                style: TextStyle(fontSize: 11, color: nc.textSecondary.withValues(alpha: 0.5)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  HapticFeedback.lightImpact();
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.copy, size: 13, color: nc.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text('复制', style: TextStyle(fontSize: 11, color: nc.textSecondary.withValues(alpha: 0.5))),
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
  const _FullscreenImage({required this.url});

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
        child: Center(child: _buildImage()),
      ),
    );
  }
}
