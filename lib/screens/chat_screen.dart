import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/chat_controller.dart';
import '../core/agent_colors.dart';
import '../widgets/agent_side_drawer.dart';
import '../widgets/agent_top_bar.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_identity_button.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_model_chip.dart';
import '../widgets/chat_new_chat_button.dart';
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
  final GlobalKey<TaskPlanPanelState> _planPanelKey = GlobalKey<TaskPlanPanelState>();
  late final ChatController _controller;
  Timer? _scrollTimer;
  bool _showScrollBottom = false;
  bool _userScrolledUp = false;

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
    final distFromBottom = max - current;
    final shouldShow = distFromBottom > 120;
    if (shouldShow != _showScrollBottom) {
      setState(() => _showScrollBottom = shouldShow);
    }
    if (distFromBottom > 60) {
      _userScrolledUp = true;
    }
  }

  void _scrollDown() {
    if (_userScrolledUp) return;
    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(milliseconds: 50), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  void _handleSend() {
    _userScrolledUp = false;
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
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
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
          drawerScrimColor: Colors.black.withValues(alpha: 0.38),
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
              await _controller.refreshSessions();
            },
            onSessionDeleted: (id) async {
              await _controller.deleteSession(id);
            },
          ),
          appBar: AgentTopBar(
            afterMenu: ChatModelChip(
              settings: _controller.aiSettings,
              onChanged: () => setState(() {}),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatNewChatButton(controller: _controller, onBeforeNew: _resetInput),
                const SizedBox(width: 8),
                const ChatIdentityButton(),
              ],
            ),
          ),
          resizeToAvoidBottomInset: true,
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollCtrl,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _controller.messages.length,
                      cacheExtent: 1500,
                      itemBuilder: (c, i) => ChatBubble(msg: _controller.messages[i], nc: nc),
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
                              border: Border.all(color: nc.divider, width: 0.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(Icons.keyboard_double_arrow_down_rounded, size: 22, color: nc.textPrimary),
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
                onAttachment: (file, type) => _controller.setAttachment(file, type),
                onClearAttachment: _controller.clearAttachment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
