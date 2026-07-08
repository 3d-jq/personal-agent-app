import 'dart:async';
import 'dart:ui';
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
    _controller.initialize();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _scrollTimer?.cancel();
    super.dispose();
  }

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

  void _onNewChat() async {
    _resetInput();
    await _controller.saveSession();
    _controller.newSession();
    await _controller.refreshSessions();
  }

  void _onSessionTap(String id) {
    if (id != _controller.currentSessionId) {
      _resetInput();
      _controller.switchSession(id).then((_) {
        widget.onSessionChanged?.call();
      });
    }
  }

  void _onSessionDeleted(String id) async {
    await _controller.deleteSession(id);
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
          drawer: _DrawerContent(
            controller: _controller,
            onSessionTap: _onSessionTap,
            onNewChat: _onNewChat,
            onSessionDeleted: _onSessionDeleted,
          ),
          appBar: AgentTopBar(
            afterMenu: _ModelChip(controller: _controller),
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
                    _MessageList(controller: _controller, scrollController: _scrollCtrl),
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
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: nc.surface.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: nc.divider, width: 0.5),
                                ),
                                child: Icon(Icons.keyboard_arrow_down, size: 18, color: nc.textPrimary),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _TaskPlanPanel(controller: _controller, planPanelKey: _planPanelKey),
              _ChatInputBar(
                controller: _controller,
                inputController: _inputCtrl,
                focusNode: _inputFocus,
                bottomSafe: bottomSafe,
                onSend: _handleSend,
                onResetInput: _resetInput,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerContent extends StatelessWidget {
  final ChatController controller;
  final ValueChanged<String> onSessionTap;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSessionDeleted;

  const _DrawerContent({
    required this.controller,
    required this.onSessionTap,
    required this.onNewChat,
    required this.onSessionDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => AgentSideDrawer(
        sessions: controller.sessions,
        currentSessionId: controller.currentSessionId,
        isLoading: controller.isLoading,
        onSessionTap: onSessionTap,
        onNewChat: onNewChat,
        onSessionDeleted: onSessionDeleted,
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  final ChatController controller;
  const _ModelChip({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.aiSettings,
      builder: (context, child) => ChatModelChip(
        settings: controller.aiSettings,
        onChanged: () {},
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final ChatController controller;
  final ScrollController scrollController;

  const _MessageList({required this.controller, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final nc = AgentColors.of(context);
        return ListView.builder(
          controller: scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          itemCount: controller.messages.length,
          cacheExtent: 500,
          itemBuilder: (c, i) => ChatBubble(
            key: ValueKey(controller.messages[i].id),
            msg: controller.messages[i],
            nc: nc,
          ),
        );
      },
    );
  }
}

class _TaskPlanPanel extends StatelessWidget {
  final ChatController controller;
  final GlobalKey<TaskPlanPanelState> planPanelKey;

  const _TaskPlanPanel({required this.controller, required this.planPanelKey});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => TaskPlanPanel(
        key: planPanelKey,
        controller: controller,
        onClose: () {
          controller.currentPlan = null;
        },
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final ChatController controller;
  final TextEditingController inputController;
  final FocusNode focusNode;
  final double bottomSafe;
  final VoidCallback onSend;
  final VoidCallback onResetInput;

  const _ChatInputBar({
    required this.controller,
    required this.inputController,
    required this.focusNode,
    required this.bottomSafe,
    required this.onSend,
    required this.onResetInput,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => ChatInputBar(
        bottomSafe: bottomSafe,
        controller: inputController,
        focusNode: focusNode,
        onSend: onSend,
        onStop: controller.stopStream,
        isLoading: controller.isLoading,
        isCompressing: controller.isCompressing,
        isAwaitingReply: controller.isWaitingUserPrompt,
        settings: controller.aiSettings,
        onChanged: () {},
        pendingFile: controller.pendingAttachment,
        pendingFileType: controller.pendingAttachmentType,
        onAttachment: (file, type) => controller.setAttachment(file, type),
        onClearAttachment: controller.clearAttachment,
      ),
    );
  }
}
