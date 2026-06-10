import 'package:flutter/material.dart';
import '../core/agent_colors.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
          child: Text(
            '发现',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              height: 1.2,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
          child: Text(
            '探索新内容',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.43,
            ),
          ),
        ),
        const ExploreCardLarge(
          imageUrl: '',
          title: '通过腿部锻炼放松一下',
        ),
        const SizedBox(height: 16),
        const ExploreCardSmall(
          imageUrl: '',
          title: '需要优缺点列表吗？',
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class ExploreCardLarge extends StatelessWidget {
  final String imageUrl;
  final String title;

  const ExploreCardLarge({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBg,
        border: Border.all(color: colors.divider, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                color: colors.primarySurface,
                child: Center(
                  child: Icon(
                    Icons.directions_run_rounded,
                    size: 64,
                    color: colors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExploreCardSmall extends StatelessWidget {
  final String imageUrl;
  final String title;

  const ExploreCardSmall({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBg,
        border: Border.all(color: colors.divider, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 120,
              height: 120,
              color: colors.primarySurface,
              child: Center(
                child: Icon(
                  Icons.question_mark_rounded,
                  size: 40,
                  color: colors.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
                height: 1.44,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
