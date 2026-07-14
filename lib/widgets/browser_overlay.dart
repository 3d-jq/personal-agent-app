import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';
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

  /// 打开即加载的默认主页：空白页，不再强行塞百度。
  /// 大模型用 browser_* 工具导航到的页面会被保留（见 initState 的 currentUrl 判断）。
  static const String _homePage = 'about:blank';

  /// URL 栏输入裸词 / 带空格句子时走的默认搜索引擎（避免 `https://天气` 直接失败）。
  /// 用无广告的 Bing 替代百度（百度首页广告过多）。
  static const String _searchEngine = 'https://www.bing.com/search?q=';

  @override
  void initState() {
    super.initState();
    _channel = widget.channel ?? BrowserChannel();
    // 首帧后：若 WebView 当前已是某个真实页面（大模型刚导航过去），则【不重载】，
    // 避免「一打开浏览器就把大模型的页面覆盖回主页」；仅当空白时才加载主页。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cur = await _channel.currentUrl();
      if (!mounted) return;
      if (cur.isEmpty || cur == _homePage) {
        _loadUrl(_homePage);
      }
    });
  }

  /// 把用户输入归一为可加载的 URL：
  /// - 已是 http(s) 链接 → 原样；
  /// - 含点且不含空格（如 example.com）→ 补 https:// 当主机名；
  /// - 其余（搜索词 / 带空格的句子）→ 走默认搜索引擎（Bing）搜索，避免 `https://天气` 直接失败且毫无反馈。
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
    return '$_searchEngine$q';
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
            // 用 PlatformViewLink + AndroidViewSurface 走 Hybrid Composition（真实 Surface），
            // 让 WebView 拿到原生触摸，滚动/点击才跟手；配 EagerGestureRecognizer 不让
            // Flutter 手势竞技场抢走滑动手势（之前用 AndroidView 虚拟显示合成会吞手势）。
            Expanded(
              child: Stack(
                children: [
                  if (Platform.isAndroid)
                    PlatformViewLink(
                      viewType: BrowserChannel.viewType,
                      onCreatePlatformView: (params) {
                        final controller =
                            PlatformViewsService.initSurfaceAndroidView(
                          id: params.id,
                          viewType: BrowserChannel.viewType,
                          layoutDirection: TextDirection.ltr,
                        );
                        controller.addOnPlatformViewCreatedListener(
                          params.onPlatformViewCreated,
                        );
                        controller.create();
                        return controller;
                      },
                      surfaceFactory: (context, controller) => AndroidViewSurface(
                        controller: controller as AndroidViewController,
                        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                          Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                        },
                        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
                      ),
                    )
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
