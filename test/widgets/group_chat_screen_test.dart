import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/models/agent.dart';
import 'package:personal_agent_app/models/agent_group.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/services/agent_group_storage.dart';
import 'package:personal_agent_app/services/agent_storage.dart';
import 'package:personal_agent_app/widgets/agent_group/group_chat_input_bar.dart';
import 'package:personal_agent_app/widgets/agent_group/group_chat_screen.dart';
import 'package:personal_agent_app/widgets/agent_group/group_message_bubble.dart';
import 'package:personal_agent_app/widgets/agent_group/group_status_bar.dart';
import 'package:personal_agent_app/widgets/agent_group/group_chat_coordinator.dart';
import 'package:personal_agent_app/widgets/ai_settings.dart';
import 'package:personal_agent_app/widgets/chat_scroll_to_bottom_button.dart';

/// 集成测试用的假数据：一个包含 1 个成员、2 条消息的群。
final _member = Agent(
  id: 'a1',
  name: 'Bot',
  avatar: 'B',
  role: '测试助手',
);
final _group = AgentGroup(
  id: 'g1',
  name: '测试群',
  agentIds: ['a1'],
  messages: [
    ChatMessage(text: '你好', isUser: true),
    ChatMessage(text: '我是 Bot', isUser: false, speakerId: 'a1'),
  ],
);

/// 回归测试数据：超过分页窗口（_pageSize=30）的大群，使列表可滚动，
/// 用于验证「重新进入群聊默认贴底（最新消息可见）」。
final _bigGroup = AgentGroup(
  id: 'g_big',
  name: '多消息群',
  agentIds: ['a1'],
  messages: [
    for (int i = 0; i < 40; i++)
      ChatMessage(
        text: 'msg-$i',
        isUser: i.isEven,
        speakerId: i.isEven ? null : 'a1',
      ),
  ],
);

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(extensions: [AgentColors.light()]),
      home: Scaffold(body: child),
    );

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await resetDependencies();
    // 保留其余真实 service，仅替换屏幕加载所需的三个依赖
    await configureDependencies();
    getIt.unregister<AISettings>();
    getIt.registerSingleton<AISettings>(FakeAISettings());
    getIt.unregister<AgentGroupStorage>();
    getIt.registerSingleton<AgentGroupStorage>(_FakeAgentGroupStorage());
    getIt.unregister<AgentStorage>();
    getIt.registerSingleton<AgentStorage>(_FakeAgentStorage());
  });

  tearDown(() async => await resetDependencies());

  group('GroupMessageBubble', () {
    testWidgets('renders system message as centered pill', (tester) async {
      await tester.pumpWidget(_wrap(GroupMessageBubble(
        msg: ChatMessage(text: 'Bot 加入了群聊', isUser: false, speakerId: 'system'),
        speaker: null,
        nc: AgentColors.light(),
      )));
      expect(find.text('Bot 加入了群聊'), findsOneWidget);
    });

    testWidgets('renders user message without header', (tester) async {
      await tester.pumpWidget(_wrap(GroupMessageBubble(
        msg: ChatMessage(text: '你好', isUser: true),
        speaker: null,
        nc: AgentColors.light(),
      )));
      expect(find.text('你好'), findsOneWidget);
      // 用户消息不应显示身份工牌（名字 Bot）
      expect(find.text('Bot'), findsNothing);
    });

    testWidgets('renders agent message with header', (tester) async {
      await tester.pumpWidget(_wrap(GroupMessageBubble(
        msg: ChatMessage(text: '我是 Bot', isUser: false, speakerId: 'a1'),
        speaker: _member,
        nc: AgentColors.light(),
      )));
      expect(find.text('我是 Bot'), findsOneWidget);
      expect(find.text('Bot'), findsWidgets); // 身份工牌上的名字
    });

    testWidgets('renders streaming placeholder without throwing',
        (tester) async {
      await tester.pumpWidget(_wrap(GroupMessageBubble(
        msg: ChatMessage(
          text: '',
          isUser: false,
          speakerId: 'a1',
          isStreaming: true,
        ),
        speaker: _member,
        nc: AgentColors.light(),
      )));
      expect(find.byType(GroupMessageBubble), findsOneWidget);
    });

    testWidgets('golden - agent message bubble', (tester) async {
      await tester.pumpWidget(_wrap(GroupMessageBubble(
        msg: ChatMessage(text: '我是 Bot', isUser: false, speakerId: 'a1'),
        speaker: _member,
        nc: AgentColors.light(),
      )));
      await expectLater(
        find.byType(GroupMessageBubble),
        matchesGoldenFile('goldens/group_message_bubble_agent.png'),
      );
    });

    testWidgets('hides empty non-streaming agent bubble without steps',
        (tester) async {
      await tester.pumpWidget(_wrap(GroupMessageBubble(
        msg: ChatMessage(text: '', isUser: false, speakerId: 'a1'),
        speaker: _member,
        nc: AgentColors.light(),
      )));
      // 空文本且无步骤的 Agent 气泡应隐藏，不渲染身份工牌
      expect(find.text('Bot'), findsNothing);
    });
  });

  group('GroupChatInputBar', () {
    late TextEditingController controller;
    late FocusNode focusNode;
    final members = [_member];

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    Widget buildWidget({
      bool busy = false,
      bool isCompressing = false,
      void Function()? onSend,
      void Function()? onStop,
      void Function()? onMention,
    }) =>
        _wrap(GroupChatInputBar(
          controller: controller,
          focusNode: focusNode,
          busy: busy,
          isCompressing: isCompressing,
          members: members,
          onSend: onSend ?? () {},
          onStop: onStop ?? () {},
          onMention: onMention ?? () {},
        ));

    testWidgets('renders text field, @ and send buttons', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('@'), findsOneWidget);
    });

    testWidgets('shows default hint when members exist', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(
        find.text('说点什么，@名字 来召唤 Agent'),
        findsOneWidget,
      );
    });

    testWidgets('shows compressing hint when compressing', (tester) async {
      await tester.pumpWidget(buildWidget(isCompressing: true));
      expect(find.text('上下文压缩中...'), findsOneWidget);
    });

    testWidgets('shows empty-group hint when no members', (tester) async {
      await tester.pumpWidget(_wrap(GroupChatInputBar(
        controller: controller,
        focusNode: focusNode,
        busy: false,
        isCompressing: false,
        members: const [],
        onSend: () {},
        onStop: () {},
        onMention: () {},
      )));
      expect(find.text('先把 Agent 拉进群再说'), findsOneWidget);
    });

    testWidgets('disables text field while compressing', (tester) async {
      await tester.pumpWidget(buildWidget(isCompressing: true));
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isFalse);
    });

    testWidgets('calls onMention when tapping @ button', (tester) async {
      var mentioned = false;
      await tester.pumpWidget(buildWidget(onMention: () => mentioned = true));
      // 第一个 GestureDetector 是 @ 按钮
      final buttons = find.byType(GestureDetector);
      await tester.tap(buttons.at(0));
      await tester.pump();
      expect(mentioned, isTrue);
    });

    testWidgets('calls onSend when text present and not busy',
        (tester) async {
      var sent = false;
      await tester.pumpWidget(buildWidget(onSend: () => sent = true));
      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump();
      // 第二个 GestureDetector 是发送按钮（第一个是 @ 按钮）
      final buttons = find.byType(GestureDetector);
      await tester.tap(buttons.at(1));
      await tester.pump();
      expect(sent, isTrue);
    });

    testWidgets('does not call onSend when text empty and not busy',
        (tester) async {
      var sent = false;
      await tester.pumpWidget(buildWidget(onSend: () => sent = true));
      final buttons = find.byType(GestureDetector);
      await tester.tap(buttons.at(1));
      await tester.pump();
      expect(sent, isFalse);
    });

    testWidgets('shows stop icon and calls onStop when busy', (tester) async {
      var stopped = false;
      await tester.pumpWidget(buildWidget(busy: true, onStop: () => stopped = true));
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isFalse);
      // 忙碌时点击发送/停止按钮 -> onStop
      final buttons = find.byType(GestureDetector);
      await tester.tap(buttons.at(1));
      await tester.pump();
      expect(stopped, isTrue);
    });
  });

  group('GroupStatusBar', () {
    testWidgets('renders round badge and participant count when active',
        (tester) async {
      await tester.pumpWidget(_wrap(GroupStatusBar(
        members: [_member],
        agentStatus: {'a1': AgentStatus.replied},
        discussionRound: 2,
        participatedAgents: {'a1'},
      )));
      expect(find.text('第 2 轮'), findsOneWidget);
      expect(find.text('1 人参与'), findsOneWidget);
    });

    testWidgets('hidden info when no discussion yet', (tester) async {
      await tester.pumpWidget(_wrap(GroupStatusBar(
        members: [_member],
        agentStatus: const {},
        discussionRound: 0,
        participatedAgents: const {},
      )));
      expect(find.text('第 0 轮'), findsNothing);
      expect(find.text('0 人参与'), findsNothing);
    });
  });

  group('GroupChatScreen integration', () {
    testWidgets('loads group and renders title + messages + agent header',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: GroupChatScreen(groupId: 'g1'),
      ));
      await tester.pumpAndSettle();

      // AppBar 标题
      expect(find.text('测试群'), findsWidgets);
      // 两条消息
      expect(find.text('你好'), findsOneWidget);
      expect(find.text('我是 Bot'), findsOneWidget);
      // Agent 身份工牌
      expect(find.text('Bot'), findsWidgets);
    });

    testWidgets('renders input bar inside the screen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: GroupChatScreen(groupId: 'g1'),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(GroupChatInputBar), findsOneWidget);
    });

    testWidgets('reopen scrolls to the latest message (bottom)',
        (tester) async {
      // 覆盖存储，返回超过分页窗口的大群，使列表可滚动
      getIt.unregister<AgentGroupStorage>();
      getIt.registerSingleton<AgentGroupStorage>(_FakeBigGroupStorage());

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: GroupChatScreen(groupId: 'g_big'),
      ));
      await tester.pumpAndSettle();

      // 重新进入后应贴底：最新消息 msg-39 可见，滚动位置位于接近最大处
      expect(find.text('msg-39'), findsOneWidget);
      final scrollable =
          tester.widget<Scrollable>(find.byType(Scrollable).first);
      final pos = scrollable.controller!.position;
      // 动态 item 高度下首跳 maxScrollExtent 偏小，两阶段校正后允许少量容差
      expect(pos.pixels, greaterThanOrEqualTo(pos.maxScrollExtent - 100));
    });

    testWidgets('wires the scroll-to-bottom button (unread pill) and clears on tap',
        (tester) async {
      // 用大群使列表可滚动、能离开底部
      getIt.unregister<AgentGroupStorage>();
      getIt.registerSingleton<AgentGroupStorage>(_FakeBigGroupStorage());

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AgentColors.light()]),
        home: GroupChatScreen(groupId: 'g_big'),
      ));
      await tester.pumpAndSettle();

      // 组件已接入到树中（贴底时由 AnimatedOpacity 隐藏，但存在）
      expect(find.byType(ChatScrollToBottomButton), findsOneWidget);
      // 无新消息时不应显示「N 条新消息」文案
      expect(find.textContaining('条新消息'), findsNothing);

      // 滚到顶部（离开底部）触发浮条锚点记录
      final scrollable =
          tester.widget<Scrollable>(find.byType(Scrollable).first);
      scrollable.controller!.jumpTo(0);
      await tester.pumpAndSettle();

      // 上滑后按钮仍在（未读为 0 时显示圆形，无文案）
      expect(find.byType(ChatScrollToBottomButton), findsOneWidget);
      expect(find.textContaining('条新消息'), findsNothing);

      // 点击回到底部：滚动回到接近最大处（说明按钮可交互且锚点已复位）
      await tester.tap(find.byType(ChatScrollToBottomButton));
      await tester.pumpAndSettle();
      final pos = scrollable.controller!.position;
      expect(pos.pixels, greaterThanOrEqualTo(pos.maxScrollExtent - 100));
    });
  });
}

/// ── Fakes ────────────────────────────────────────────────────────────

class FakeAISettings extends AISettings {
  @override
  Future<void> load() async {
    // 跳过文件 IO，保持测试隔离
  }
}

class _FakeAgentGroupStorage implements AgentGroupStorage {
  @override
  Future<List<AgentGroup>> loadAll() async => [_group];

  @override
  Future<void> save(AgentGroup g) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  AgentGroup? byId(String id) => id == _group.id ? _group : null;

  @override
  void clearCache() {}
}

class _FakeBigGroupStorage implements AgentGroupStorage {
  @override
  Future<List<AgentGroup>> loadAll() async => [_bigGroup];

  @override
  Future<void> save(AgentGroup g) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  AgentGroup? byId(String id) => id == _bigGroup.id ? _bigGroup : null;

  @override
  void clearCache() {}
}

class _FakeAgentStorage implements AgentStorage {
  @override
  Future<List<Agent>> loadAll() async => [_member];

  @override
  Future<Agent> add(Agent a) async => a;

  @override
  Future<void> update(Agent a) async {}

  @override
  Future<void> remove(String id) async {}

  @override
  Agent? byId(String id) => id == _member.id ? _member : null;

  @override
  Agent? byName(String name) => name == _member.name ? _member : null;

  @override
  void clearCache() {}
}
