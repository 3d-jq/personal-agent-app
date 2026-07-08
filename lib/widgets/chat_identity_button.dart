import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import '../core/app_router.dart';
import '../services/context_doc_service.dart';
import 'context_docs_panel.dart';

class ChatIdentityButton extends StatelessWidget {
  const ChatIdentityButton({super.key});

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: nc.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 44),
        color: nc.surface,
        onSelected: (value) {
          HapticFeedback.lightImpact();
          if (value == '__scratch__') {
            AppRouter.toScratchViewer(context);
          } else {
            AppRouter.toContextDocViewer(
              context,
              doc: ContextDoc.values.firstWhere((d) => d.name == value),
            );
          }
        },
        itemBuilder: (_) => [
          ...ContextDoc.values
              .where((doc) => doc != ContextDoc.knowledge)
              .map((doc) => PopupMenuItem<String>(
                    value: doc.name,
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(children: [
                        Icon(ContextDocViewerPage.iconFor(doc), size: 20, color: nc.textPrimary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(ContextDocViewerPage.titleFor(doc),
                              style: TextStyle(fontSize: 15, color: nc.textPrimary, fontWeight: FontWeight.w400)),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: nc.textSecondary.withValues(alpha: 0.5)),
                      ]),
                    ),
                  )),
          PopupMenuItem<String>(
            value: '__scratch__',
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(Icons.article, size: 20, color: nc.textPrimary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('AI 草稿纸',
                      style: TextStyle(fontSize: 15, color: nc.textPrimary, fontWeight: FontWeight.w400)),
                ),
                Icon(Icons.chevron_right, size: 18, color: nc.textSecondary.withValues(alpha: 0.5)),
              ]),
            ),
          ),
        ],
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.badge, size: 18, color: nc.textPrimary),
        ),
      ),
    );
  }
}
