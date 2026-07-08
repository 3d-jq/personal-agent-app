import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import 'common_widgets.dart';
import '../services/log_service.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  String _logs = '';
  int _logSize = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await log.getLogs();
    final size = await log.getLogSize();
    if (mounted) {
      setState(() {
        _logs = logs;
        _logSize = size;
        _loading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
        title: '运行日志',
        actions: [
          IconButton(
            icon: Icon(Icons.content_copy, color: nc.textSecondary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _logs));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已复制日志'), duration: Duration(seconds: 1)),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete, color: nc.error),
            onPressed: () async {
              await log.clearLogs();
              _loadLogs();
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: nc.primary))
          : Column(
              children: [
                // 日志信息栏
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: nc.surface,
                  child: Row(
                    children: [
                      Icon(Icons.description, size: 16, color: nc.textSecondary),
                      SizedBox(width: 8),
                      Text(
                        '日志大小：${_formatSize(_logSize)}',
                        style: TextStyle(fontSize: 13, color: nc.textSecondary),
                      ),
                      Spacer(),
                      Text(
                        '${_logs.split('\n').length} 行',
                        style: TextStyle(fontSize: 13, color: nc.textSecondary),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: nc.divider),
                // 日志内容
                Expanded(
                  child: _logs.isEmpty
                      ? Center(
                          child: Text(
                            '暂无日志',
                            style: TextStyle(color: nc.textSecondary, fontSize: 14),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(16),
                          child: SelectableText(
                            _logs,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: nc.textPrimary,
                              height: 1.6,
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
