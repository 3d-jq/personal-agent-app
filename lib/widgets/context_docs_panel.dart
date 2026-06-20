import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../core/agent_colors.dart';
import '../services/context_doc_service.dart';

/// Markdown 身份文档查看页。
class ContextDocViewerPage extends StatelessWidget {
  final ContextDoc doc;

  const ContextDocViewerPage({super.key, required this.doc});

  static String titleFor(ContextDoc doc) {
    return switch (doc) {
      ContextDoc.soul => 'AI 人格',
      ContextDoc.user => '用户资料',
      ContextDoc.agent => '任务经验',
      ContextDoc.memory => '长期记忆',
    };
  }

  static IconData iconFor(ContextDoc doc) {
    return switch (doc) {
      ContextDoc.soul => Icons.psychology_alt_outlined,
      ContextDoc.user => Icons.person_outline,
      ContextDoc.agent => Icons.lightbulb_outline,
      ContextDoc.memory => Icons.bookmark_outline,
    };
  }

  static String subtitleFor(ContextDoc doc) {
    return switch (doc) {
      ContextDoc.soul => 'AI 的人格与风格',
      ContextDoc.user => '你的信息与偏好',
      ContextDoc.agent => '任务经验与技巧',
      ContextDoc.memory => '跨场景长期记忆',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AgentColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          titleFor(doc),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.textPrimary),
        ),
      ),
      body: FutureBuilder<String>(
        future: ContextDocService().read(doc),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.textSecondary));
          }
          final content = snapshot.data ?? '';
          return Markdown(
            data: content,
            selectable: true,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              h1: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: colors.textPrimary),
              h2: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.textPrimary),
              h3: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.textPrimary),
              p: TextStyle(fontSize: 15, height: 1.6, color: colors.textPrimary),
              listBullet: TextStyle(fontSize: 15, color: colors.textPrimary),
              blockquote: TextStyle(fontSize: 14, color: colors.textSecondary, fontStyle: FontStyle.italic),
              blockquoteDecoration: BoxDecoration(
                border: Border(left: BorderSide(color: colors.divider, width: 3)),
              ),
            ),
          );
        },
      ),
    );
  }
}
