import 'dart:io';

import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../platform/browser_channel.dart';

/// 浏览器全屏浮层：在对话主界面之上覆盖一个原生 [WebView] 可视化面板，
/// 并提供 URL 栏、快照面板、后退与关闭。对齐 Operit 的 ComputerScreen/WorkspaceScreen。
///
/// 该浮层把共享的 Kotlin 原生 WebView（[BrowserChannel] 驱动）直接嵌入 Flutter，
/// 既能手动浏览，也能被 AI 的 browser_* 工具自动化操作（同一个 WebView 实例）。
class BrowserOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const BrowserOverlay({super.key, required this.onClose});

  @override
  State<BrowserOverlay> createState() => _BrowserOverlayState();
}

class _BrowserOverlayState extends State<BrowserOverlay> {
  final BrowserChannel _channel = BrowserChannel();
  final TextEditingController _urlCtrl = TextEditingController();
  List<BrowserElement> _elements = const [];
  bool _snapOpen = false;
  bool _busy = false;
  String _error = '';

  Future<void> _go() async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;
    final url = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
    _urlCtrl.text = url;
    setState(() => _busy = true);
    try {
      await _channel.loadUrl(url);
      if (mounted) setState(() => _error = '');
    } on BrowserException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _snapshot() async {
    setState(() => _busy = true);
    try {
      final els = await _channel.snapshot();
      if (mounted) {
        setState(() {
          _elements = els;
          _snapOpen = true;
          _error = '';
        });
      }
    } on BrowserException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _back() async {
    try {
      await _channel.back();
    } on BrowserException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final topPad = MediaQuery.of(context).padding.top;
    return Material(
      color: nc.background,
      child: RepaintBoundary(
        child: Column(
          children: [
            SizedBox(height: topPad),
            // ── 顶部工具条：后退 / URL / 关闭 ──
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: nc.background,
                border: Border(bottom: BorderSide(color: nc.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: nc.textPrimary),
                    onPressed: _busy ? null : _back,
                    tooltip: '后退',
                  ),
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: nc.bgSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: TextField(
                          controller: _urlCtrl,
                          onSubmitted: (_) => _go(),
                          textInputAction: TextInputAction.go,
                          decoration: InputDecoration.collapsed(
                            hintText: '输入网址，如 example.com',
                            hintStyle: TextStyle(color: nc.textTertiary, fontSize: 14),
                          ),
                          style: TextStyle(color: nc.textPrimary, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: nc.textPrimary),
                    onPressed: widget.onClose,
                    tooltip: '关闭浏览器',
                  ),
                ],
              ),
            ),
            // ── 原生 WebView ──
            Expanded(
              child: Stack(
                children: [
                  if (Platform.isAndroid)
                    const AndroidView(viewType: BrowserChannel.viewType)
                  else
                    Center(
                      child: Text(
                        '浏览器功能仅 Android 支持',
                        style: TextStyle(color: nc.textSecondary),
                      ),
                    ),
                  if (_busy)
                    const Center(child: CircularProgressIndicator.adaptive()),
                ],
              ),
            ),
            // ── 底部操作条 ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: nc.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _error.isEmpty
                          ? '可直接浏览，或让 AI 用 browser_* 工具自动操作'
                          : _error,
                      style: TextStyle(
                        color: _error.isEmpty ? nc.textSecondary : nc.error,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _snapshot,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('快照'),
                  ),
                ],
              ),
            ),
            // ── 快照元素面板 ──
            if (_snapOpen)
              Container(
                height: 196,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: nc.divider, width: 0.5)),
                  color: nc.background,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 4),
                          child: Text(
                            '页面元素（${_elements.length}）',
                            style: TextStyle(
                              color: nc.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, size: 18, color: nc.textSecondary),
                          onPressed: () => setState(() => _snapOpen = false),
                          tooltip: '收起',
                        ),
                      ],
                    ),
                    Expanded(
                      child: _elements.isEmpty
                          ? Center(
                              child: Text(
                                '页面暂无可见可交互元素',
                                style: TextStyle(color: nc.textSecondary, fontSize: 12),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _elements.length,
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, color: nc.divider),
                              itemBuilder: (_, i) {
                                final e = _elements[i];
                                final subtitle = e.text.isNotEmpty
                                    ? e.text
                                    : (e.placeholder.isNotEmpty
                                        ? e.placeholder
                                        : (e.href.isNotEmpty ? e.href : ''));
                                return ListTile(
                                  dense: true,
                                  leading: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: nc.primarySurface,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      e.tag,
                                      style: TextStyle(
                                        color: nc.primary,
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    '[${e.ref}] ${subtitle.isEmpty ? '(无文本)' : subtitle}',
                                    style: TextStyle(
                                        color: nc.textPrimary, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
