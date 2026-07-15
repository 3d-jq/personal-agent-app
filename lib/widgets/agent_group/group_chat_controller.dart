import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/models/agent.dart';
import 'package:personal_agent_app/models/agent_group.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/services/agent_group_storage.dart';
import 'package:personal_agent_app/services/agent_runner.dart';
import 'package:personal_agent_app/services/agent_storage.dart';
import 'package:personal_agent_app/services/ai_service.dart';
import 'package:personal_agent_app/services/chat_stream_event.dart';
import 'package:personal_agent_app/services/connectivity_service.dart';
import 'package:personal_agent_app/services/history_manager.dart';
import 'package:personal_agent_app/services/log_service.dart';
import 'package:personal_agent_app/screens/chat_helpers.dart';
import 'package:personal_agent_app/tools/tools.dart';
import 'package:personal_agent_app/widgets/agent_group/agent_group_theme.dart';
import 'package:personal_agent_app/widgets/agent_group/group_chat_coordinator.dart';
import 'package:personal_agent_app/widgets/ai_settings.dart';
import 'package:personal_agent_app/widgets/agent_group/group_chat_runner.dart';
import 'package:personal_agent_app/widgets/agent_group/group_dispatch_models.dart';
import 'package:personal_agent_app/widgets/agent_group/group_message_window.dart';
import 'package:personal_agent_app/widgets/agent_group/group_context_usage.dart';

/// 群聊的「状态 + 编排」控制器。
///
/// 把原先混在 [GroupChatScreen] 的 State 里的全部状态（消息、成员、调度状态、
/// 分页窗口、活跃流、上下文压缩管理器）与编排逻辑（发送、接力、自动选人、
/// 持久化）下沉到这里。页面只负责渲染 + 把用户操作转交给本控制器，
/// 从而：可独立单元测、状态变更集中可预测、避免 `setState` 满天飞、降低
/// Widget 生命周期复杂度导致的 flake。
///
/// 渲染层通过 [ListenableBuilder] 监听本控制器；单条消息自身是
/// `ChatMessage`(ChangeNotifier)，流式期间仅对应气泡局部重建。
class GroupChatController extends ChangeNotifier {
  GroupChatController({required this.groupId}) {
    // 构造期从 getIt 取依赖：测试 setUp 已注册 Fake，真实运行已 configureDependencies，
    // 两种场景构造时 getIt 均已就绪。
    _aiSettings = getIt<AISettings>();
    _baseRegistry = ToolRegistry();
    if (_baseRegistry.all.isEmpty) registerAllTools(_baseRegistry);
    _runner = AgentRunner(baseRegistry: _baseRegistry);
  }

  final String groupId;

  late final AISettings _aiSettings;
  late final ToolRegistry _baseRegistry;
  late final AgentRunner _runner;
  GroupChatCoordinator? _coordinator;

  AgentGroup? _group;
  List<ChatMessage> _messages = [];
  /// 压缩生成的「发送视图」（含摘要气泡），供非隔离 Agent 构建 history 使用。
  /// 与单聊对称：压缩只影响发送给模型的视图，不替换 _messages（完整历史保留
  /// 供 UI 展示与 saveGroup 落盘）。未压缩时为 null，回退到 _messages。
  List<ChatMessage>? _historyView;
  List<Agent> _members = [];
  Map<String, Agent> _byId = {};
  Map<String, Agent> _byName = {};
  bool _busy = false;
  bool _stopped = false;
  bool _isCompressing = false;

  // ── Agent 状态跟踪 ──
  Map<String, AgentStatus> _agentStatus = {};
  int _discussionRound = 0;
  final Set<String> _participatedAgents = {};

  // ── 派活工具串行锁与上限（工具调用派活模式用） ──
  final _dispatchLock = SerialLock();
  int _dispatchCount = 0;
  static const int _maxDelegates = 5;

  /// 本轮协调者调用 delegate_task 的派发记录（用于把协调者气泡转为派发卡片）。
  final List<DispatchRecord> _activeDispatches = [];

  // ── Stop 完整取消：管理所有活跃流 ──
  final List<StreamSubscription<ChatStreamEvent>> _activeSubs = [];

  // ── 中止信号与在跑子任务（供「停止」取消在飞执行） ──
  // _abortSignal 由 stop() 完成，中断协调者自身仍在进行的执行流；
  // _activeChildRuns 记录每个在跑子 Agent 的独立 abort，供「停止」精准终止某一在跑子 Agent。
  Completer<void>? _abortSignal;
  final Map<String, ChildRun> _activeChildRuns = {};

  // ── 长会话分页窗口（逻辑收拢至 GroupMessageWindow） ──
  final GroupMessageWindow _window = GroupMessageWindow();

  // ── 上下文压缩管理器 ──
  HistoryManager? _historyManager;
  HistoryManager get _historyManagerInstance {
    final hm = _historyManager ??= HistoryManager(
      contextWindowSize: _aiSettings.contextWindowSize,
      maxOutputTokens: 4096,
      keepTokens: 8000,
    );
    // 窗口大小可能在 AI 设置中变更，需同步到 HistoryManager——其压缩阈值与
    // 压缩判断都依赖 contextWindowSize。否则改窗口后阈值/节点位置会固化在旧值。
    if (hm.contextWindowSize != _aiSettings.contextWindowSize) {
      hm.contextWindowSize = _aiSettings.contextWindowSize;
    }
    return hm;
  }

  /// 滚动回调：由页面在 initState 注入（页面持有 ScrollController）。
  VoidCallback? onScroll;

  bool _disposed = false;

  // ── 对外只读状态（页面渲染用） ──
  AgentGroup? get group => _group;
  List<ChatMessage> get messages => _messages;
  List<Agent> get members => _members;
  Map<String, Agent> get byId => _byId;
  bool get busy => _busy;
  bool get isCompressing => _isCompressing;
  Map<String, AgentStatus> get agentStatus => _agentStatus;
  int get discussionRound => _discussionRound;
  Set<String> get participatedAgents => _participatedAgents;
  int get windowStart => _window.start;
  bool get hasEarlier => _window.hasEarlier;

  // ── 上下文窗口占用（供 UI 可视化，估算与缓存收拢至 GroupContextUsage）──
  final GroupContextUsage _usage = GroupContextUsage();
  /// 系统提示（群名/描述/成员角色）估算 token，计入面板占用展示。
  int? _systemPromptTokens;
  /// 当前对话估算占用的 token 数（消息估算 + 系统提示估算，均为字符启发式，非真实分词）。
  /// 缓存与估算逻辑委托给 [GroupContextUsage]。
  int get estimatedContextTokens => _usage.compute(
        messages: _messages,
        systemPromptTokens: _systemPromptTokens ?? 0,
        estimateMessages: _historyManagerInstance.estimateMessagesTokens,
      );
  /// 上下文窗口大小（token 数）。
  int get contextWindowSize => _aiSettings.contextWindowSize;
  /// 触发压缩的 token 阈值。
  int get contextCompressionThreshold => _historyManagerInstance.compressionThreshold;
  /// 占用率（0~1+），估算值。
  double get contextUsageRatio =>
      contextWindowSize > 0 ? estimatedContextTokens / contextWindowSize : 0.0;

  /// dispose 后不再通知，避免 ChangeNotifier 断言崩溃。
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    // 注意：界面关闭（pop）时**不要**取消正在跑的对话 / 工具流。
    // 群聊的流式任务应像单聊一样在后台继续跑完，并由 runGroupAgentMessage
    // 在 finally 里自动存盘（saveGroup）；否则退出界面会中断模型、丢失整个回复。
    // 用户主动停止请调用 [stop]，那里才会真正取消订阅。
    _disposed = true;
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────

  Future<void> load() async {
    await _aiSettings.load();
    final g = (await getIt<AgentGroupStorage>().loadAll())
        .where((x) => x.id == groupId)
        .firstOrNull;
    if (g == null) {
      _notify();
      return;
    }
    final allAgents = await getIt<AgentStorage>().loadAll();
    final ms = g.agentIds
        .map((id) => allAgents.where((a) => a.id == id).firstOrNull)
        .whereType<Agent>()
        .toList();

    // 自动清理：移除不存在的 Agent
    final validIds = ms.map((a) => a.id).toSet();
    final invalidIds =
        g.agentIds.where((id) => !validIds.contains(id)).toList();
    if (invalidIds.isNotEmpty) {
      g.agentIds.removeWhere((id) => !validIds.contains(id));
      await getIt<AgentGroupStorage>().save(g);
    }

    // 清洗历史消息中可能残留的模型控制标记（如 [[reply_to_current]]）
    final loadedMessages = List<ChatMessage>.from(g.messages);
    for (final m in loadedMessages) {
      if (!m.isUser) m.text = stripArtifactTokens(m.text);
    }

    _group = g;
    _messages = loadedMessages;
    _members = ms;
    _byId = {for (final a in ms) a.id: a};
    _byName = {for (final a in ms) a.name: a};
    _coordinator = GroupChatCoordinator(
      aiSettings: _aiSettings,
      members: ms,
    );
    _window.reset(_messages.length);
    _notify();
  }

  /// 编辑群资料后应用：补系统消息、存盘、重载。
  Future<void> applyGroupUpdate(AgentGroup updated) async {
    final g = _group;
    if (g == null) return;
    final oldMemberIds = Set<String>.from(g.agentIds);
    final newMemberIds = Set<String>.from(updated.agentIds);

    final addedIds = newMemberIds.difference(oldMemberIds);
    final removedIds = oldMemberIds.difference(newMemberIds);

    final allAgents = await getIt<AgentStorage>().loadAll();
    for (final id in addedIds) {
      final agent = allAgents.where((a) => a.id == id).firstOrNull;
      if (agent != null) {
        _messages.add(ChatMessage(
          text: '${agent.name} 加入了群聊',
          isUser: false,
          speakerId: 'system',
        ));
      }
    }
    for (final id in removedIds) {
      final agent = allAgents.where((a) => a.id == id).firstOrNull;
      if (agent != null) {
        _messages.add(ChatMessage(
          text: '${agent.name} 离开了群聊',
          isUser: false,
          speakerId: 'system',
        ));
      }
    }

    updated.messages = List.from(_messages);
    await getIt<AgentGroupStorage>().save(updated);
    await load();
  }

  Future<void> saveGroup() async {
    final g = _group;
    if (g == null) return;
    g.messages = List.from(_messages);
    await getIt<AgentGroupStorage>().save(g);
  }

  /// 发送用户消息并驱动整个协作流程。
  Future<void> send(String text) async {
    if (_group == null || _busy) return;
    _busy = true;
    final mentionNames = parseMentions(text, _members);
    final mentionAgents = mentionNames
        .map((n) => _byName[n])
        .whereType<Agent>()
        .toList();

    _messages.add(
      ChatMessage(text: text, isUser: true, mentions: mentionNames),
    );
    _notify();
    onScroll?.call();

    final hasDirectMentions = mentionAgents.isNotEmpty;

    if (!await getIt<ConnectivityService>().check()) {
      _messages.add(ChatMessage(
        text: '当前无网络连接，请检查网络后重试',
        isUser: false,
        speakerId: 'system',
      ));
      _notify();
      await saveGroup();
      onScroll?.call();
      _busy = false;
      return;
    }

    if (!_aiSettings.hasVendor) {
      _messages.add(ChatMessage(
        text: '请先在侧边栏设置中配置 AI 后端',
        isUser: false,
        speakerId: 'system',
      ));
      _notify();
      await saveGroup();
      onScroll?.call();
      _busy = false;
      return;
    }

    // ── 混合协作引擎 ──
    // 每次发消息前刷新 MCP 工具，确保新连接的服务器能被大模型发现
    registerAllTools(_baseRegistry);

    // 压缩仅生成「发送视图」，不替换 _messages——完整群聊历史保留在 _messages
    // 供 UI 展示与 saveGroup 落盘。后续每个非隔离 Agent 通过 _historyView 引用
    // 该视图（见 _runOneAndAppend），既避免历史永久丢失，也避免二次截断把摘要切掉。
    // 系统提示占用计入面板上下文统计（之前只算消息、漏算群名/描述/成员角色）。
    _systemPromptTokens = _historyManagerInstance.estimateTokens(
      estimateGroupSystemPrompt(_group, _members),
    );
    List<ChatMessage> sendView = _messages;
    try {
      _isCompressing = true;
      _notify();
      final compressed = await _historyManagerInstance.compressIfNeeded(
        _messages,
        (messages) async {
          final response = await AIService(
            baseUrl: _aiSettings.baseUrl,
            apiKey: _aiSettings.apiKey,
            model: _aiSettings.effectiveModel,
            thinkingEffort: _aiSettings.thinkingEffort,
            isAnthropic: _aiSettings.selectedVendor?.isAnthropic ?? false,
            provider: _aiSettings.selectedVendor?.name ?? '',
          ).summarize(messages);
          return response;
        },
        systemPromptTokens: _systemPromptTokens!,
      );
      sendView = identical(compressed, _messages) ? _messages : compressed;
    } catch (e) {
      log.w('GroupChatController', 'Compression failed, sending full history', e);
      sendView = _messages;
    } finally {
      _isCompressing = false;
      _notify();
    }
    _historyView = identical(sendView, _messages) ? null : sendView;

    _discussionRound = 0;
    _participatedAgents.clear();
    _dispatchCount = 0;
    // 初始化所有 Agent 状态为 idle
    _agentStatus = {for (final m in _members) m.id: AgentStatus.idle};
    _notify();
    _stopped = false;
    _abortSignal = Completer<void>();
    try {
      final handled = <String>{};
      const maxRounds = 5;

      final coordinator = _members.where((a) => a.isCoordinator).firstOrNull;

      if (coordinator == null) {
        // 兜底：群里没有协调者时，退回旧的「自动选人 + @接力」模式
        if (hasDirectMentions) {
          for (final a in mentionAgents) {
            if (_stopped) break;
            handled.add(a.id);
            _discussionRound++;
            _participatedAgents.add(a.id);
            _agentStatus[a.id] = AgentStatus.thinking;
            _notify();
            await _runOneAndAppend(a, abortSignal: _abortSignal, onFinish: (o) => _applyOutcome(a.id, o));
          }
          await _handleRelay(handled, maxRounds);
        } else {
          final speakerName = await _autoPickSpeaker();
          if (speakerName != null && speakerName != 'STOP') {
            final firstAgent = _byName[speakerName];
            if (firstAgent != null) {
              handled.add(firstAgent.id);
              _discussionRound++;
              _participatedAgents.add(firstAgent.id);
              _agentStatus[firstAgent.id] = AgentStatus.thinking;
              _notify();
            await _runOneAndAppend(firstAgent, abortSignal: _abortSignal, onFinish: (o) => _applyOutcome(firstAgent.id, o));
              await _handleRelay(handled, maxRounds);
            }
          }
        }
        return;
      }

      // ── 协调者主导模式（工具调用派活） ──
      // 协调者永远是「第一棒」：理解需求 → 用 delegate_task 工具派活给子 Agent
      // → 在子 Agent 回答后做汇总。问用户（自然语言）与派活（工具调用）结构性分离，
      // 不再依赖解析 @名字 文本，从根上消除「漏派 / 误派 / 未答先派」的脆弱性。
      if (hasDirectMentions) {
        // 用户显式 @ 了某些 Agent → 先让这些被点名的子 Agent 直接回复（用户明确意图）
        final directSubAgents =
            mentionAgents.where((a) => a.id != coordinator.id).toList();
        final userMentionedCoordinator =
            mentionAgents.any((a) => a.id == coordinator.id);
        for (final a in directSubAgents) {
          if (_stopped) break;
          handled.add(a.id);
          _discussionRound++;
          _participatedAgents.add(a.id);
          _agentStatus[a.id] = AgentStatus.thinking;
          _notify();
          await _runOneAndAppend(a);
          _agentStatus[a.id] = AgentStatus.replied;
          _notify();
        }
        // 协调者收尾：综合已有回复做汇总，必要时再用 delegate_task 追加派活
        if (userMentionedCoordinator || directSubAgents.isNotEmpty) {
          await _runCoordinatorWithDispatch(coordinator, handled);
        }
      } else {
        // 用户没 @ 任何人 → 协调者作为第一棒，自行决定派活或亲自答
        await _runCoordinatorWithDispatch(coordinator, handled);
      }
    } finally {
      _busy = false;
      _notify();
      // _saveGroup 已在 _runOneAndAppend 中调用，此处不再重复
    }
  }

  /// 让协调者跑一轮：带 [delegate_task] 派活工具。
  /// 协调者要么用自然语言回复（问用户 / 亲自答），要么调用 delegate_task
  /// 把子任务派给子 Agent（在隔离上下文执行），二者不会混淆。
  ///
  /// 关键行为：若协调者本轮通过 delegate_task 派活过，则它本轮生成的自然语言
  /// （通常是收尾汇总）会被**移到所有子 Agent 回答之后的末尾气泡**呈现，
  /// 原占位气泡只保留派发动作（时间线），保证「派发 → 子 Agent 答 → 主 Agent
  /// 简短收尾」的阅读顺序，避免总结出现在派发位置之前。
  Future<void> _runCoordinatorWithDispatch(
    Agent coordinator,
    Set<String> handled,
  ) async {
    if (_stopped || handled.contains(coordinator.id)) return;
    handled.add(coordinator.id);
    _discussionRound++;
    _participatedAgents.add(coordinator.id);
    _agentStatus[coordinator.id] = AgentStatus.thinking;
    _notify();
    _activeDispatches.clear();
    final result = await _runOneAndAppend(
      coordinator,
      dispatchTools: _coordinatorDispatchTools(),
      abortSignal: _abortSignal,
      onFinish: (o) => _applyOutcome(coordinator.id, o),
    );
    // 安全网：delegate_task 同步等待子 Agent 完成后会从 _activeChildRuns 移除句柄，
    // 正常情况下此处已为空；若异常泄漏则主动 abort 并清理，保证收尾顺序正确。
    if (_activeChildRuns.isNotEmpty) {
      for (final run in _activeChildRuns.values) {
        if (!run.abort.isCompleted) run.abort.complete();
      }
      _activeChildRuns.clear();
    }
    final placeholder = result.placeholder;
    // 派活过：把本轮自然语言收尾移到末尾气泡，原气泡只留派发时间线。
    if (_activeDispatches.isNotEmpty) {
      final summaryText = placeholder.text.trim();
      placeholder.text = '';
      if (summaryText.isNotEmpty) {
        _messages.add(
          ChatMessage(
            text: summaryText,
            isUser: false,
            speakerId: coordinator.id,
          ),
        );
        _ensureTailVisible();
      }
      await saveGroup();
    }
    _notify();
  }

  /// 构造协调者专属工具集：派活（delegate_task）。
  /// 子 Agent 被视为协调者可调度的「任务」，由 delegate_task 派活后由「停止」统一取消。
  List<AgentTool> _coordinatorDispatchTools() {
    return [
      DelegateTaskTool(onDelegate: _onDelegateTask),
    ];
  }

  /// delegate_task 工具的业务实现：
  /// 找到子 Agent → 在隔离上下文（用户原始需求 + 任务简报）中跑一次 → 返回其文本。
  /// 用串行锁保证多个委派逐个执行，状态更新可预测；用 _dispatchCount 上限防失控。
  Future<String> _onDelegateTask(String agentName, String brief) async {
    if (_stopped) {
      return '派活已停止（用户点击了停止）。请停止委派并汇总已有结果。';
    }
    if (_dispatchCount >= _maxDelegates) {
      return '已达到本次对话的最大委派数量（$_maxDelegates），请停止委派子 Agent，直接汇总已有结果。';
    }
    final child = _byName[agentName];
    if (child == null) {
      final known = _members.map((a) => a.name).join('、');
      return '派活失败：找不到名为「$agentName」的子 Agent。已知成员：$known。'
          '请使用准确的群内名字。';
    }
    _dispatchCount++;
    _activeDispatches.add(DispatchRecord(agentName, brief));
    // 注册可取消的子任务句柄：供「停止」在派活执行期间中断它。
    // 该子 Agent 作为协调者可调度的「任务」，出错/超时/被终止时把结果回灌协调者。
    final childAbort = Completer<void>();
    _activeChildRuns[child.id] = ChildRun(agent: child, abort: childAbort);
    try {
      final childText = await _dispatchLock.run(() async {
        _discussionRound++;
        _participatedAgents.add(child.id);
        _agentStatus[child.id] = AgentStatus.thinking;
        _notify();
        final userReq = _messages.lastWhere(
          (m) => m.isUser,
          orElse: () => ChatMessage(text: '', isUser: true),
        );
        final coordinatorId =
            _members.where((a) => a.isCoordinator).firstOrNull?.id ?? '';
        final briefMsg = ChatMessage(
          text: brief,
          isUser: false,
          speakerId: coordinatorId,
        );
        final isolated = <ChatMessage>[userReq, briefMsg];
        final result = await _runOneAndAppend(
          child,
          isolatedContext: isolated,
          abortSignal: childAbort,
          onFinish: (o) => _applyOutcome(child.id, o),
        );
        final text = result.text;
        _agentStatus[child.id] = AgentStatus.replied;
        _notify();
        return text;
      });
      return childText.isNotEmpty ? childText : '（子 Agent 无文本输出）';
    } finally {
      _activeChildRuns.remove(child.id);
    }
  }

  /// 把子 Agent 执行结局映射为状态栏可见的 [AgentStatus]。
  void _applyOutcome(String agentId, ChildOutcome outcome) {
    _agentStatus[agentId] = switch (outcome) {
      ChildOutcome.ok || ChildOutcome.cancelled => AgentStatus.replied,
      ChildOutcome.error => AgentStatus.error,
      ChildOutcome.timeout => AgentStatus.timeout,
    };
    _notify();
  }

  /// 处理 Agent 接力：
  /// 1) 若最新回复 @ 了其他子 Agent，则让被 @ 的人接话（本地解析，零额外 LLM）；
  /// 2) 若无人被 @、且刚刚发言的是子 Agent（非协调者），则给协调者（主 Agent）
  ///    一次「汇总轮」收尾，之后强制结束，避免死循环。
  Future<void> _handleRelay(Set<String> handled, int maxRounds) async {
    // 调度权只在主 Agent（协调者）手中：子 Agent 只执行被指派的任务，不反向派活。
    final coordinatorId =
        _members.where((a) => a.isCoordinator).firstOrNull?.id;
    for (var round = 0; round < maxRounds && !_stopped; round++) {
      // 获取最新的 Agent 回复（排除系统消息）
      final lastAgentMsg = _messages.lastWhere(
        (m) => !m.isUser && m.speakerId != null && m.speakerId != 'system',
        orElse: () => ChatMessage(text: '', isUser: false),
      );

      if (lastAgentMsg.text.isEmpty) break;

      // ── 是否允许委派 ──
      // 1) 只有主 Agent 的 @ 才触发接力；子 Agent 的 @ 不触发（调度权独占）。
      // 2) 主 Agent 若正在向用户收集需求（本轮含提问），先不委派，等用户回答后再派活。
      final canDispatch = coordinatorId != null &&
          lastAgentMsg.speakerId == coordinatorId &&
          !_isAskingUser(lastAgentMsg.text);

      if (canDispatch) {
        final relayMentions = parseMentions(lastAgentMsg.text, _members);
        final relayAgents = relayMentions
            .map((n) => _byName[n])
            .whereType<Agent>()
            .where((a) => !handled.contains(a.id))
            .toList();

        if (relayAgents.isNotEmpty) {
          // 主 Agent 委派 → 子 Agent 隔离执行（只给它「用户原始需求 + 任务简报」）
          final userReq = _findUserRequestBefore(lastAgentMsg);
          final briefMsg = ChatMessage(
            text: lastAgentMsg.text,
            isUser: false,
            speakerId: coordinatorId,
          );
          final isolated = <ChatMessage>[
            if (userReq != null) userReq,
            briefMsg,
          ];
          for (final a in relayAgents) {
            if (_stopped) break;
            handled.add(a.id);
            _discussionRound++;
            _participatedAgents.add(a.id);
            _agentStatus[a.id] = AgentStatus.thinking;
            _notify();
            await _runOneAndAppend(a, isolatedContext: isolated, abortSignal: _abortSignal, onFinish: (o) => _applyOutcome(a.id, o));
          }
          continue;
        }
      }

      // 无人被委派（或本轮不该委派）→ 若最后发言是子 Agent，主 Agent 做一轮汇总收尾；否则结束。
      final lastSpeaker = lastAgentMsg.speakerId == null
          ? null
          : _byId[lastAgentMsg.speakerId];
      if (coordinatorId != null &&
          lastSpeaker != null &&
          !lastSpeaker.isCoordinator) {
        handled.add(coordinatorId);
        _discussionRound++;
        _participatedAgents.add(coordinatorId);
        _agentStatus[coordinatorId] = AgentStatus.thinking;
        _notify();
          await _runOneAndAppend(_byId[coordinatorId]!, abortSignal: _abortSignal, onFinish: (o) => _applyOutcome(coordinatorId, o));
          break; // 汇总后强制结束，避免与子 Agent 无限接力
      }

      break;
    }
  }

  /// 判断主 Agent 的回复是否主要在向用户提问（收集需求）。
  /// 含问号且以问号结尾，或含问号且有提问措辞 → 视为在提问，本轮不应委派子 Agent。
  bool _isAskingUser(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    final hasQ = t.contains('？') || t.contains('?');
    if (!hasQ) return false;
    if (t.endsWith('？') || t.endsWith('?')) return true;
    return RegExp(
      r'(你想|请问|多少|几天|预算|偏好|打算|告诉我|需要|可以|是否|哪|什么|怎么|吗)',
    ).hasMatch(t);
  }

  /// 自动调度：系统判断哪个 Agent 应该回复
  Future<String?> _autoPickSpeaker() {
    return _coordinator!.autoPickSpeaker(
      group: _group,
      messages: _messages,
      speakerNames: {for (final a in _members) a.id: a.name},
    );
  }

  /// 执行一个 Agent 并把它加入消息流，回复后立即存盘。
  /// 流式重逻辑已抽取到 [runGroupAgentMessage]（group_chat_runner.dart）。
  /// 执行一个 Agent 并把它加入消息流，回复后立即存盘。
  /// 流式重逻辑已抽取到 [runGroupAgentMessage]（group_chat_runner.dart）。
  ///
  /// 返回该 Agent 的占位气泡 [ChatMessage] 与其最终文本，便于调用方（如协调者轮）
  /// 在流式结束后对气泡做二次加工（例如把协调者气泡降级为派发卡片）。
  ///
  /// [isolatedContext] 非空时，子 Agent 只看这份隔离上下文（用户原始需求 + 主 Agent
  /// 的任务简报），不看全量群历史——实现「编排者-工作者」隔离执行，避免子 Agent 被
  /// 无关对话干扰、也防止它去翻前面的对话自行发挥。
  Future<({ChatMessage placeholder, String text, ChildOutcome outcome})>
      _runOneAndAppend(
    Agent agent, {
    List<ChatMessage>? isolatedContext,
    List<AgentTool>? dispatchTools,
    Completer<void>? abortSignal,
    void Function(ChildOutcome)? onFinish,
  }) async {
    final placeholder = ChatMessage(
      text: '',
      isUser: false,
      speakerId: agent.id,
      isStreaming: true,
    );
    _messages.add(placeholder);
    _ensureTailVisible(); // 活跃讨论时贴底显示该 Agent 的回复
    _notify();
    onScroll?.call();
    final history = isolatedContext ??
        (_historyView ?? _messages).where((m) => m != placeholder).toList();
    final (text, outcome) = await runGroupAgentMessage(
      agent: agent,
      vendors: _aiSettings.vendors,
      selectedVendor: _aiSettings.selectedVendor,
      thinkingEffort: _aiSettings.thinkingEffort,
      history: history,
      memberNames: _members.map((a) => a.name).toList(),
      speakerNames: {for (final a in _members) a.id: a.name},
      memberRoles: {for (final a in _members) a.name: a.role},
      groupName: _group?.name ?? '',
      groupDesc: _group?.description ?? '',
      placeholder: placeholder,
      runner: _runner,
      activeSubs: _activeSubs,
      onScroll: () => onScroll?.call(),
      onChanged: _notify,
      dispatchTools: dispatchTools,
      abortSignal: abortSignal,
      onFinish: onFinish,
    );
    // 每个 Agent 回复后立即保存，防止中途崩溃丢失数据
    await saveGroup();
    return (placeholder: placeholder, text: text, outcome: outcome);
  }

  /// 保证窗口末尾对齐最新消息（活跃讨论时始终显示最新）
  void _ensureTailVisible() => _window.ensureTailVisible(_messages.length);

  /// 找到 [dispatch] 之前最近的一条用户消息，作为子 Agent 隔离执行的「原始需求」，
  /// 让子 Agent 即便不看全量历史也能理解用户到底在问什么。
  ChatMessage? _findUserRequestBefore(ChatMessage dispatch) {
    final idx = _messages.indexOf(dispatch);
    if (idx < 0) return null;
    for (int i = idx - 1; i >= 0; i--) {
      if (_messages[i].isUser) return _messages[i];
    }
    return null;
  }

  /// 加载更早的消息：窗口向前提一页（滚动位置保持由页面 anchor 负责）。
  void loadEarlierPage() {
    _window.loadEarlierPage();
    _notify();
  }

  /// 完整停止：取消所有活跃流并解除 busy。
  void stop() {
    _stopped = true;
    // 终止所有在飞的子 Agent 执行（让其 runGroupAgentMessage 以「[已被终止]」收尾并回灌协调者）
    for (final run in _activeChildRuns.values) {
      if (!run.abort.isCompleted) run.abort.complete();
    }
    // 终止协调者自身的执行流
    _abortSignal?.complete();
    for (final s in _activeSubs.toList()) {
      s.cancel();
    }
    _activeSubs.clear();
    _busy = false;
    _notify();
  }
}
