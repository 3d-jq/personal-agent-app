import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../models/reminder.dart';
import '../core/service_locator.dart';
import '../services/reminder_storage.dart';
import '../tools/reminder_tool.dart';

class RemindersView extends StatefulWidget {
  const RemindersView({super.key});
  @override
  State<RemindersView> createState() => _RemindersViewState();
}

class _RemindersViewState extends State<RemindersView> {
  final _storage = getIt<ReminderStorage>();
  List<Reminder> _reminders = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _storage.addListener(_onStorageChanged);
    _load();
  }

  @override
  void dispose() {
    _storage.removeListener(_onStorageChanged);
    super.dispose();
  }

  void _onStorageChanged() {
    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    _reminders = await _storage.loadAll();
    if (!mounted) return;
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
        title: Text(
          '定时任务',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: nc.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
          ? _emptyState(nc)
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _reminders.length,
              itemBuilder: (_, i) => _reminderCard(_reminders[i], nc),
            ),
    );
  }

  Widget _emptyState(AgentColors nc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.alarm_off_rounded,
            size: 48,
            color: nc.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            '没有定时任务',
            style: TextStyle(
              fontSize: 15,
              color: nc.textSecondary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '在聊天中让 DWeis 帮你设置提醒',
            style: TextStyle(
              fontSize: 13,
              color: nc.textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderCard(Reminder r, AgentColors nc) {
    final now = DateTime.now();
    final isPast = r.scheduledTime.isBefore(now);
    final statusColor = r.isCompleted
        ? nc.textSecondary.withValues(alpha: 0.4)
        : isPast
        ? nc.textSecondary.withValues(alpha: 0.4)
        : nc.success;
    final statusText = r.isCompleted
        ? '已完成'
        : isPast
        ? '已过期'
        : '等待中';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: nc.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (r.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              r.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: nc.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: nc.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                _formatTime(r.scheduledTime),
                style: TextStyle(
                  fontSize: 11,
                  color: nc.textSecondary.withValues(alpha: 0.5),
                ),
              ),
              const Spacer(),
              if (!r.isCompleted && !isPast)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _cancelReminder(r);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _cancelReminder(Reminder r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消提醒'),
        content: Text('确定要取消「${r.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ReminderTool.cancelReminder(r.id);
              _load();
            },
            child: const Text('取消提醒', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.isNegative) return '已过期';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟后';
    if (diff.inHours < 24) return '${diff.inHours}小时后';
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
