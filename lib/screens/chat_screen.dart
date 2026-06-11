import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../core/agent_colors.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/ai_service.dart';
import '../services/chat_storage.dart';
import '../services/memory_storage.dart';
import '../services/notification_service.dart';
import '../tools/tools.dart';
import '../widgets/agent_top_bar.dart';
import '../widgets/agent_side_drawer.dart';
import '../widgets/ai_settings_sheet.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';

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
  final AISettings _aiSettings = AISettings();
  final ToolRegistry _toolRegistry = ToolRegistry();
  final ChatStorage _storage = ChatStorage();
  StreamSubscription<String>? _aiStream;
  Timer? _scrollTimer;
  bool _isLoading = false;
  bool _loaded = false;

  String? _sessionId;
  List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];

  String? get currentSessionId => _sessionId;

  @override
  void initState() {
    super.initState();
    _initTools();
    _aiSettings.load().then((_) async {
      if (!mounted) return;
      _sessions = await _storage.loadAll();
      final sid = widget.sessionId ?? (_sessions.isNotEmpty ? _sessions.first.id : null);
      if (sid != null) {
        await _loadSession(sid);
      } else {
        _newSession();
      }
      setState(() => _loaded = true);
    });
  }

  void _initTools() {
    _toolRegistry.register(FileTool());
    _toolRegistry.register(ClipboardTool());
    _toolRegistry.register(ReminderTool());
    _toolRegistry.register(WebFetchTool());
    final weatherTool = WeatherTool();
    final searchTool = WebSearchTool();
    final imageTool = AgnesImageTool()
      ..apiKey = 'sk-3STpwSvUPUyYP1LIUc4O2yGjrEqapMPm2XNUPgmd0sa7IwaJ';
    final videoTool = AgnesVideoTool()
      ..apiKey = 'sk-3STpwSvUPUyYP1LIUc4O2yGjrEqapMPm2XNUPgmd0sa7IwaJ';
    _toolRegistry.register(weatherTool);
    _toolRegistry.register(searchTool);
    _toolRegistry.register(imageTool);
    _toolRegistry.register(videoTool);
    _toolRegistry.register(SaveMemoryTool());
    _toolRegistry.register(SaveNoteTool());
    _toolRegistry.register(TimeTool());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    _scrollTimer?.cancel();
    _aiStream?.cancel();
    super.dispose();
  }

  void _newSession() {
    _sessionId = const Uuid().v4();
    _messages = [];
    _inputCtrl.clear();
    setState(() {});
  }

  Future<void> _loadSession(String id) async {
    _sessionId = id;
    final sessions = await _storage.loadAll();
    final session = sessions.where((s) => s.id == id).firstOrNull;
    _messages = session?.messages.map((m) => ChatMessage(
      text: m.text,
      isUser: m.isUser,
    )).toList() ?? [];
    _inputCtrl.clear();
  }

  Future<void> _saveSession() async {
    if (_sessionId == null || _messages.isEmpty) return;
    final title = _messages
        .where((m) => m.isUser)
        .firstOrNull
        ?.text
        .replaceAll('\n', ' ')
        .substring(0, _messages.first.text.length.clamp(0, 30))
        .trim() ?? '新对话';
    await _storage.save(ChatSession(
      id: _sessionId!,
      title: title,
      messages: _messages.map((m) => ChatMessage(text: m.text, isUser: m.isUser)).toList(),
      updatedAt: DateTime.now(),
    ));
    _storage.clearCache();
    _sessions = await _storage.loadAll();
  }

  void _switchSession(String id) {
    _saveSession().then((_) {
      _loadSession(id).then((_) {
        setState(() {});
        widget.onSessionChanged?.call();
      });
    });
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

  void _stopStream() {
    _aiStream?.cancel();
    _aiStream = null;
    final aiMsg = _messages.isNotEmpty && !_messages.last.isUser
        ? _messages.last
        : null;
    if (aiMsg != null) {
      aiMsg.isStreaming = false;
      if (aiMsg.text.isEmpty) aiMsg.text = '(已停止)';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isLoading) return;
    if (_sessionId == null) _newSession();
    if (!_aiSettings.hasVendor) {
      setState(() => _messages.add(ChatMessage(
          text: '请先配置 AI 后端（点击输入框内存图标）', isUser: false)));
      _inputCtrl.clear();
      _inputFocus.unfocus();
      _scrollDown();
      return;
    }
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messages.add(ChatMessage(text: '', isUser: false, isStreaming: true));
      _isLoading = true;
    });
    _inputCtrl.clear();
    _inputFocus.unfocus();
    _scrollDown();

    final storage = MemoryStorage();
    await storage.loadAll();
    final prefs = storage.preferencePrompt;
    final memories = storage.memoryContext;
    final systemPrompt = StringBuffer('你是一个叫DWeis的全能agent助手，你可以使用可用的工具来帮助用户完成任务。当用户要求记录、总结、保存、记下某些内容时，调用 save_note 工具保存为笔记。');
    if (prefs.isNotEmpty) {
      systemPrompt.write('\n\n## 用户偏好\n$prefs');
    }
    if (memories.isNotEmpty) {
      systemPrompt.write('\n\n## 用户记忆\n$memories');
    }

    final history = <Map<String, dynamic>>[{'role': 'system', 'content': systemPrompt.toString()}];
    for (final m in _messages) {
      if (m.isStreaming) continue;
      history.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      });
    }
    history.removeWhere((m) => (m['content'] ?? '').isEmpty);

    final ai = AIService(
      baseUrl: _aiSettings.baseUrl,
      apiKey: _aiSettings.apiKey,
      providerName: _aiSettings.selectedVendor?.name ?? '',
      model: _aiSettings.effectiveModel,
      toolRegistry: _toolRegistry,
    );
    final aiMsg = _messages.last;
    final buf = StringBuffer();
    final steps = <TimelineStep>[];
    var firstChunk = true;
    var hasToolCalls = false;

    void finishRunning() {
      for (var i = 0; i < steps.length; i++) {
        if (steps[i].status == TimelineStepStatus.running) {
          steps[i].status = TimelineStepStatus.done;
        }
      }
    }

    try {
      _aiStream = ai.sendMessageStream(history).listen(
        (chunk) {
          buf.write(chunk);
          if (firstChunk) {
            firstChunk = false;
            steps.add(TimelineStep(label: '思考中', type: TimelineStepType.thinking, status: TimelineStepStatus.running));
          }
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.startsWith('🔧 调用工具:')) {
              hasToolCalls = true;
              finishRunning();
              final name = line.replaceFirst('🔧 调用工具:', '').trim();
              steps.add(TimelineStep(label: _toolLabel(name), type: TimelineStepType.tool, status: TimelineStepStatus.running));
              // Notification for long-running tools
              if (name == 'generate_image' || name == 'generate_video') {
                NotificationService().startTask(id: name, title: _toolLabel(name), message: '准备中…');
              }
            } else if (line.startsWith('✅') && line.contains('完成')) {
              final name = line.replaceFirst('✅', '').replaceFirst('完成', '').trim();
              final idx = steps.lastIndexWhere((s) => s.type == TimelineStepType.tool && s.label == _toolLabel(name) && s.status == TimelineStepStatus.running);
              if (idx >= 0) steps[idx].status = TimelineStepStatus.done;
              steps.add(TimelineStep(label: '思考中', type: TimelineStepType.thinking, status: TimelineStepStatus.running));
              if (name == 'generate_image' || name == 'generate_video') {
                NotificationService().complete(id: name, title: _toolLabel(name), message: '已完成');
              }
            }
          }
          setState(() {
            aiMsg.text = buf.toString();
            aiMsg.steps = List.unmodifiable(steps);
          });
          _scrollDown();
        },
        onDone: () {
          finishRunning();
          setState(() {
            aiMsg.isStreaming = false;
            aiMsg.steps = steps.isEmpty ? null : List.unmodifiable(steps);
            if (aiMsg.cleanText.isEmpty && !hasToolCalls) aiMsg.text = '(无响应)';
            _isLoading = false;
          });
          _saveSession();
        },
        onError: (e) {
          setState(() {
            aiMsg.text = '错误: $e';
            aiMsg.isStreaming = false;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        aiMsg.text = '错误: $e';
        aiMsg.isStreaming = false;
        _isLoading = false;
      });
    }
  }

  Widget _buildModelChip(AgentColors nc) {
    final vendor = _aiSettings.selectedVendor;
    if (vendor == null || vendor.model.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModelPicker(context, _aiSettings, () => setState(() {}));
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: nc.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(vendor.model, style: TextStyle(fontSize: 12, color: nc.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: nc.textSecondary),
          ],
        ),
      ),
    );
  }

  String _toolLabel(String name) {
    switch (name) {
      case 'weather': return '查询天气';
      case 'web_search': return '搜索网页';
      case 'web_fetch': return '获取网页';
      case 'reminder': return '设置提醒';
      case 'file_manager': return '文件管理';
      case 'clipboard': return '剪贴板';
      case 'generate_image': return '生成图片';
      case 'generate_video': return '生成视频';
      case 'save_memory': return '记忆';
      case 'save_note': return '保存笔记';
      case 'get_current_time': return '获取时间';
      default: return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: nc.background,
        systemNavigationBarIconBrightness: Brightness.dark,
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
            sessions: _sessions,
            currentSessionId: _sessionId,
            onSessionTap: (id) {
              if (id != _sessionId) _switchSession(id);
            },
            onNewChat: () {
              _saveSession().then((_) {
                _newSession();
                setState(() => _sessions = []);
                _storage.loadAll().then((s) => setState(() => _sessions = s));
              });
            },
            onSessionDeleted: (id) async {
              await _storage.delete(id);
              _sessions = await _storage.loadAll();
              if (id == _sessionId) {
                _newSession();
              }
              setState(() {});
            },
            onReopenDrawer: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                _scaffoldKey.currentState?.openDrawer();
              });
            },
          ),
          appBar: AgentTopBar(afterMenu: _buildModelChip(nc)),
          resizeToAvoidBottomInset: true,
          body: Column(children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (c, i) => ChatBubble(msg: _messages[i], nc: nc),
              ),
            ),
            ChatInputBar(
              bottomSafe: bottomSafe,
              controller: _inputCtrl,
              focusNode: _inputFocus,
              onSend: _sendMessage,
              onStop: _stopStream,
              isLoading: _isLoading,
              settings: _aiSettings,
              onChanged: () => setState(() {}),
            ),
          ]),
        ),
      ),
    );
  }
}
