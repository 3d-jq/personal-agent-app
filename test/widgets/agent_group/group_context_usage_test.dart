import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/models/agent.dart';
import 'package:personal_agent_app/models/agent_group.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/widgets/agent_group/group_context_usage.dart';

void main() {
  group('estimateGroupSystemPrompt', () {
    test('包含群名、群描述与成员名/角色', () {
      final group = AgentGroup(
        id: 'g1',
        name: '测试群',
        description: '一个测试项目群',
        agentIds: const ['c', 'x'],
      );
      final members = [
        Agent(id: 'c', name: 'DWeis', role: '协调者'),
        Agent(id: 'x', name: '小助手', role: '执行'),
      ];
      final text = estimateGroupSystemPrompt(group, members);
      expect(text, contains('测试群'));
      expect(text, contains('一个测试项目群'));
      expect(text, contains('DWeis'));
      expect(text, contains('小助手'));
    });

    test('无群时仅拼成员', () {
      final members = [Agent(id: 'c', name: 'DWeis', role: '协调者')];
      final text = estimateGroupSystemPrompt(null, members);
      expect(text, contains('DWeis'));
      expect(text, isNot(contains('测试群')));
    });
  });

  group('GroupContextUsage 估算与缓存', () {
    test('compute 把消息估算与系统提示 token 相加', () {
      final u = GroupContextUsage();
      final msgs = [ChatMessage(text: 'a', isUser: false)];
      final tokens = u.compute(
        messages: msgs,
        systemPromptTokens: 100,
        estimateMessages: (m) => m.length * 10,
      );
      expect(tokens, 110); // 100 + 1*10
    });

    test('引用/条数/长度/流式状态未变时复用缓存，不重复估算', () {
      var calls = 0;
      int estimate(List<ChatMessage> m) {
        calls++;
        return m.length * 10;
      }

      final u = GroupContextUsage();
      final msgs = [ChatMessage(text: 'a', isUser: false)];
      final first = u.compute(
        messages: msgs,
        systemPromptTokens: 100,
        estimateMessages: estimate,
      );
      final second = u.compute(
        messages: msgs,
        systemPromptTokens: 100,
        estimateMessages: estimate,
      );
      expect(second, first);
      expect(calls, 1); // 第二次命中缓存

      // 仅最后一条文本长度变化 → 必须触发重算
      msgs.last.text = 'aaaa';
      final third = u.compute(
        messages: msgs,
        systemPromptTokens: 100,
        estimateMessages: estimate,
      );
      expect(calls, 2);
      expect(third, first); // 值相同（条数没变），但确实重算了
    });

    test('ratio 计算占用率（0~1+）', () {
      final u = GroupContextUsage();
      expect(u.ratio(128000, 256000), closeTo(0.5, 1e-9));
      expect(u.ratio(0, 256000), 0.0);
      expect(u.ratio(0, 0), 0.0); // 防除零
    });
  });
}
