import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/chat_controller.dart';
import '../core/agent_colors.dart';
import '../core/app_router.dart';
import '../services/context_doc_service.dart';
import '../widgets/agent_side_drawer.dart';
import '../widgets/agent_top_bar.dart';
import '../widgets/ai_settings_sheet.dart';
import '../widgets/context_docs_panel.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/task_plan_panel.dart';

class ChatScreen extends StatefulWidget {
  final String? sessionId;
  final VoidCallback? onSessionChanged;
  const ChatScreen({super.key, this.sessionId, this.onSessionChanged});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey<TaskPlanPanelState> _planPanelKey =
      GlobalKey<TaskPlanPanelState>();
  late final ChatController _controller;
  Timer? _scrollTimer;
  bool _showScrollBottom = false;

  @override
  void initState() {
    super.initState();
    _controller = ChatController(
      initialSessionId: widget.sessionId,
      onNeedScroll: _scrollDown,
    );
    _controller.addListener(_onControllerChanged);
    _controller.initialize();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _scrollTimer?.cancel();
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final current = _scrollCtrl.position.pixels;
    final shouldShow = (max - current) > 120;
    if (shouldShow != _showScrollBottom) {
      setState(() => _showScrollBottom = shouldShow);
    }
  }

  void _scrollDown() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _inputCtrl.text;
    if (_controller.isWaitingUserPrompt) {
      _resetInput();
      _controller.submitUserPromptResponse(text);
    } else {
      _resetInput();
      _controller.sendMessage(text);
    }
  }

  void _resetInput() {
    _inputCtrl.clear();
    _inputFocus.unfocus();
  }

  Widget _buildIdentityButton(AgentColors nc) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: nc.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
              .map(
            (doc) => PopupMenuItem<String>(
              value: doc.name,
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      ContextDocViewerPage.iconFor(doc),
                      size: 20,
                      color: nc.textPrimary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        ContextDocViewerPage.titleFor(doc),
                        style: TextStyle(
                          fontSize: 15,
                          color: nc.textPrimary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: nc.textSecondary.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuItem<String>(
            value: '__scratch__',
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 20,
                    color: nc.textPrimary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'AI 草稿纸',
                      style: TextStyle(
                        fontSize: 15,
                        color: nc.textPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: nc.textSecondary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ],
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: nc.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(Icons.badge_outlined, size: 18, color: nc.textPrimary),
        ),
      ),
    );
  }

  Widget _buildModelChip(AgentColors nc) {
    final vendor = _controller.aiSettings.selectedVendor;
    if (vendor == null || vendor.model.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModelPicker(context, _controller.aiSettings, () => setState(() {}));
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: nc.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              vendor.model,
              style: TextStyle(
                fontSize: 12,
                color: nc.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: nc.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: nc.background,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: GestureDetector(
        onTap: () {
          if (!(_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
            _inputFocus.unfocus();
          }
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: nc.background,
          drawerEnableOpenDragGesture: false,
          drawerScrimColor: Colors.black38,
          drawer: AgentSideDrawer(
            sessions: _controller.sessions,
            currentSessionId: _controller.currentSessionId,
            isLoading: _controller.isLoading,
            onSessionTap: (id) {
              if (id != _controller.currentSessionId) {
                _resetInput();
                _controller.switchSession(id).then((_) {
                  widget.onSessionChanged?.call();
                });
              }
            },
            onNewChat: () async {
              _resetInput();
              await _controller.saveSession();
              _controller.newSession();
              _controller.clearSessions();
              await _controller.refreshSessions();
            },
            onSessionDeleted: (id) async {
              await _controller.deleteSession(id);
            },
          ),
          appBar: AgentTopBar(
            afterMenu: _buildModelChip(nc),
            trailing: _buildIdentityButton(nc),
          ),
          resizeToAvoidBottomInset: true,
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _controller.messages.length,
                      cacheExtent: 1500,
                      itemBuilder: (c, i) =>
                          ChatBubble(msg: _controller.messages[i], nc: nc),
                    ),
                    if (_showScrollBottom)
                      Positioned(
                        right: 16,
                        bottom: 12,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _scrollCtrl.animateTo(
                              _scrollCtrl.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                            );
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: nc.surface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.keyboard_double_arrow_down_rounded,
                              size: 22,
                              color: nc.textPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              TaskPlanPanel(key: _planPanelKey, controller: _controller),
              ChatInputBar(
                bottomSafe: bottomSafe,
                controller: _inputCtrl,
                focusNode: _inputFocus,
                onSend: _handleSend,
                onStop: _controller.stopStream,
                isLoading: _controller.isLoading,
                isAwaitingReply: _controller.isWaitingUserPrompt,
                settings: _controller.aiSettings,
                onChanged: () => setState(() {}),
                pendingFile: _controller.pendingAttachment,
                pendingFileType: _controller.pendingAttachmentType,
                onAttachment: (file, type) =>
                    _controller.setAttachment(file, type),
                onClearAttachment: _controller.clearAttachment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
