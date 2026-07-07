import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../core/service_locator.dart';
import '../services/virtual_fs.dart';
import 'state_placeholder.dart';

/// AI 草稿纸查看页。
///
/// 展示虚拟文件系统 /scratch/ 下的文件列表，
/// 让用户了解 AI 在复杂任务中记录的中间结果。
class ScratchViewerPage extends StatefulWidget {
  const ScratchViewerPage({super.key});

  @override
  State<ScratchViewerPage> createState() => _ScratchViewerPageState();
}

class _ScratchViewerPageState extends State<ScratchViewerPage> {
  bool _loading = true;
  String? _error;
  List<String> _files = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fs = getIt<VirtualFileSystem>();
      final files = await fs.walk('/scratch');
      if (!mounted) return;
      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openFile(String path) async {
    try {
      final fs = getIt<VirtualFileSystem>();
      final content = await fs.read('/$path');
      if (!mounted) return;
      _showContent(path, content);
    } catch (e) {
      if (!mounted) return;
      _showError('读取失败', '$e');
    }
  }

  void _showContent(String name, String content) {
    final nc = AgentColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: nc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) {
        final bottom = MediaQuery.of(c).padding.bottom;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (c, scrollCtrl) {
            return Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: nc.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(PhosphorIconsRegular.x, size: 18, color: nc.textSecondary),
                          onPressed: () => Navigator.pop(c),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: content.trim().isEmpty
                        ? Center(
                            child: Text(
                              '（空文件）',
                              style: TextStyle(
                                fontSize: 15,
                                color: nc.textSecondary,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(
                              content,
                              style: TextStyle(
                                fontSize: 13,
                                color: nc.textPrimary,
                                height: 1.5,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showError(String title, String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AgentColors.of(c).surface,
        title: Text(title, style: TextStyle(color: AgentColors.of(c).textPrimary)),
        content: Text(msg, style: TextStyle(color: AgentColors.of(c).textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIconsRegular.caretLeft, size: 18, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AI 草稿纸',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: nc.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(PhosphorIconsRegular.arrowsClockwise, size: 20, color: nc.textSecondary),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(nc),
    );
  }

  Widget _buildBody(AgentColors nc) {
    if (_loading) {
      return StatePlaceholder.loading();
    }

    if (_error != null) {
      return StatePlaceholder.error(
        title: _error,
        onRetry: _load,
      );
    }

    if (_files.isEmpty) {
      return StatePlaceholder.empty(
        icon: PhosphorIconsRegular.bookOpen,
        title: '草稿纸是空的',
        subtitle: 'AI 执行复杂任务时，中间结果会写到这里',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _files.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (c, i) {
        final file = _files[i];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openFile(file),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: nc.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIconsRegular.fileText, size: 18, color: nc.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      file,
                      style: TextStyle(fontSize: 15, color: nc.textPrimary),
                    ),
                  ),
                  Icon(PhosphorIconsRegular.caretRight, size: 16, color: nc.textSecondary.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}