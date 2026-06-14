import 'package:flutter/material.dart';
import '../providers/daily_card_provider.dart';

class DailyCardDialog extends StatelessWidget {
  final DailyCardProvider provider;
  const DailyCardDialog({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 400),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('☀️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                provider.greeting ?? '早上好！新的一天 ✨',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Color(0xFF37352F), height: 1.6, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(_todayLabel(), style: const TextStyle(fontSize: 13, color: Color(0xFF9B9A97))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF37352F),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('👋 知道了', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    final months = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二'];
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '${now.year}年${months[now.month - 1]}月${now.day}日 星期${weekdays[now.weekday - 1]}';
  }
}
