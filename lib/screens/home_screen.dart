import 'package:flutter/material.dart';
import '../core/agent_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '你好 嘉权',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '有哪些新鲜事？',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.43,
            ),
          ),
        ],
      ),
    );
  }
}
