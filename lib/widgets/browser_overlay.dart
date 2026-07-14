import 'dart:io';

import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../platform/browser_channel.dart';
import '../services/log_service.dart';

/// 浏览器全屏浮层：在对话主界面之上覆盖一个原生 [WebView] 可视化面板，
/// 并提供 URL 栏、快照面板、后退与关闭。对齐 Operit 的 ComputerScreen/WorkspaceScreen。
///
/// 该浮层把共享的 Kotlin 原生 WebView（[BrowserChannel] 驱动）直接嵌入 Flutter，
/// 既能手动浏览，也能被 AI 的 browser_* 工具自动化操作（同一个 WebView 实例）。
class BrowserOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final BrowserChannel? channel;

  const BrowserOverlay({super.key, required this.onClose, this.channel});

  @override
  State<BrowserOverlay> createState() => _BrowserOverlayState();
}

class _BrowserOverlayState extends State<BrowserOverlay> {
  late final BrowserChannel _channel;
  final TextEditingController _urlCtrl = TextEditingController();
  List<BrowserElement> _elements = const [];
  bool _snapOpen = false;
  bool _busy = false;
  String _error = '';

  /// 打开即加载的默认主页：避免空白 WebView 让用户以为「什么都没显示」。
  static const String _homePage = 'https://www.baidu.com';

  @override
  void initState() {
    super.initState();
    _channel = widget.channel ?? BrowserChannel();
    // 首帧后加载默认主页（不阻塞 UI）。即使 WebView 尚未 attach，原生也会先导航，
    // attach 后立即可见，解决「打开浏览器一片空白」的体感问题。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadUrl(_homePage);
    });
  }

  /// 把用户输入归一为可加载的 URL：
  /// - 已是 http(s) 链接 → 原样；
  /// - 含点且不含空格（如 example.com）→ 补 https:// 当主机名；
  /// - 其余（搜索词 / 带空格的句子）→ 走 Baidu 搜索，避免 `https://天气` 直接失败且毫无反馈。
  String _normalizeUrl(String raw) {
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.contains('.') && !trimmed.contains(' ')) {
      return 'https://$trimmed';
    }
    final q = Uri.encodeQueryComponent(trimmed);
    return 'https://www.baidu.com/s?wd=$q';
  }

  Future<void> _go() async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;
    final url = _normalizeUrl(raw);
    _urlCtrl.text = url;
    await _loadUrl(url);
  }

  /// 加载指定 URL：统一处理加载态与失败报错（失败写入 App 运行日志）。
  Future<void> _loadUrl(String url) async {
    setState(() => _busy = true);
    try {
      await _channel.loadUrl(url);
      if (mounted) setState(() => _error = '');
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
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
      log.e('Browser', e.message, e.cause);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _back() async {
    try {
      await _channel.back();
    } on BrowserException catch (e) {
      log.e('Browser', e.message, e.cause);
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
                            hintText: '输入网址或搜索词',
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
