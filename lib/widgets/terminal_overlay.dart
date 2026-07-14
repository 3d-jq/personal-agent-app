import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import '../core/agent_colors.dart';
import '../platform/terminal_channel.dart';
import '../services/log_service.dart';

/// 终端沙箱全屏浮层：在对话主界面之上覆盖一个 xterm 终端面板，
/// 接入 Kotlin 原生 PRoot + Ubuntu 环境（[TerminalChannel] 驱动）。
///
/// 与 [BrowserOverlay] 同一模式：既能手动在沙箱里敲命令，也能被 AI 的
/// terminal_run 工具在后台无头执行（两者共用同一套原生环境）。
class TerminalOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final TerminalChannel? channel;

  const TerminalOverlay({super.key, required this.onClose, this.channel});

  @override
  State<TerminalOverlay> createState() => _TerminalOverlayState();
}

class _TerminalOverlayState extends State<TerminalOverlay> {
  late final TerminalChannel _channel;
  final Terminal _terminal = Terminal();
  StreamSubscription<Uint8List>? _sub;
  bool _ready = false;
  bool _busy = false;
  String _error = '';

  static const String _sessionId = 'main';

  @override
  void initState() {
    super.initState();
    _channel = widget.channel ?? TerminalChannel();
    // 用户输入 → 原样发回 PTY（UTF-8 字符串）。
    _terminal.onOutput = (data) {
      // 忽略未就绪时的输入；错误吞掉，避免崩终端。
      _channel.write(_sessionId, data).catchError((_) => true);
    };
    _initTerminal();
  }

  Future<void> _initTerminal() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      // 关键：先订阅输出流，再启动会话，避免丢失首屏 shell 提示符。
      await _sub?.cancel();
      _sub = _channel.output.listen(
        (bytes) {
          try {
            final str = utf8.decode(bytes, allowMalformed: true);
            _terminal.write(str);
          } catch (_) {
            // 解码异常忽略，不中断终端。
          }
        },
        onError: (e) {
          if (mounted) setState(() => _error = '终端输出流异常: $e');
        },
      );
      await _channel.ensureReady();
      await _channel.start(_sessionId);
      if (mounted) setState(() => _ready = true);
    } on TerminalException catch (e) {
      log.e('Terminal', e.message, e.cause);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // xterm 4.0.0 无公开 clear()，用 ANSI 转义清屏 + 清滚动回滚 + 光标归位。
  void _clear() => _terminal.write('\x1b[2J\x1b[3J\x1b[H');

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    // 关闭会话（忽略异常，宿主已在 detach 时清理）。
    _channel.close(_sessionId).catchError((_) => true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final topPad = MediaQuery.of(context).padding.top;
    return Material(
      color: Colors.black,
      child: RepaintBoundary(
        child: Column(
          children: [
            SizedBox(height: topPad),
            // ── 顶部工具条：标题 / 清空 / 关闭 ──
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: const BoxDecoration(
                color: Colors.black,
                border: Border(bottom: BorderSide(color: Colors.white12, width: 0.5)),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.terminal, color: nc.primary, size: 20),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        '终端沙箱',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cleaning_services, color: Colors.white70, size: 20),
                    onPressed: _busy ? null : _clear,
                    tooltip: '清空',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                    tooltip: '关闭终端',
                  ),
                ],
              ),
            ),
            // ── 终端主体 ──
            Expanded(
              child: Container(
                color: Colors.black,
                child: !_ready
                    ? Center(
                        child: _error.isEmpty
                            ? const CircularProgressIndicator.adaptive()
                            : Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  _error,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                      )
                    : TerminalView(
                        _terminal,
                        theme: TerminalThemes.whiteOnBlack,
                        backgroundOpacity: 1.0,
                        autofocus: true,
                      ),
              ),
            ),
            // ── 底部状态条 ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
                color: Colors.black,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _error.isEmpty
                          ? '用户在沙箱内敲命令，或让 AI 用 terminal_run 工具自动执行'
                          : _error,
                      style: TextStyle(
                        color: _error.isEmpty ? Colors.white54 : Colors.redAccent,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
