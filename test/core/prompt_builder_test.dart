import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/prompt_builder.dart';

void main() {
  group('PromptBuilder.buildMainPrompt 记忆规则', () {
    test('包含 USER.md 维护指引（规则 9）', () {
      final p = PromptBuilder.buildMainPrompt(
        soulContext: '',
        userContext: '',
      );
      expect(p, contains('USER.md'));
      expect(p, contains('context_doc_update'));
    });

    test('包含 MEMORY.md 维护指引（跨会话事实持久化）', () {
      final p = PromptBuilder.buildMainPrompt(
        soulContext: '',
        userContext: '',
      );
      expect(p, contains('MEMORY.md'));
      expect(p, contains('跨会话'));
      expect(p, contains('不要自己脑补'));
    });

    test('包含 AGENT.md 维护指引（规则 12：任务经验沉淀，需 reviewed=true）', () {
      final p = PromptBuilder.buildMainPrompt(
        soulContext: '',
        userContext: '',
      );
      expect(p, contains('AGENT.md'));
      expect(p, contains('reviewed=true'));
      expect(p, contains('SOUL.md'));
    });

    test('首次见面分支包含三个必填问题（称呼 + AI名 + 语气）', () {
      final p = PromptBuilder.buildMainPrompt(
        soulContext: '',
        userContext: '',
        isFirstMeeting: true,
        hasExistingProfile: false,
      );
      expect(p, contains('first_meeting'));
      expect(p, contains('context_doc_update'));
      expect(p, contains('怎么称呼 ta'));
      expect(p, contains('怎么叫你'));
      expect(p, contains('语气风格'));
    });

    test('有 persona/user_profile 时注入 persona_constraints', () {
      final p = PromptBuilder.buildMainPrompt(
        soulContext: '# SOUL\n语气：可爱温柔',
        userContext: '# USER\n怎么称呼：小张',
      );
      expect(p, contains('persona_constraints'));
      expect(p, contains('你就是 <persona>'));
      expect(p, contains('怎么称呼'));
      expect(p, contains('怎么叫我'));
    });

    test('空 persona/user_profile 时不注入人格一致性约束', () {
      final p = PromptBuilder.buildMainPrompt(
        soulContext: '',
        userContext: '',
      );
      expect(p, isNot(contains('persona_constraints')));
    });

    test('system 不注入当前时间（保证前缀稳定可缓存）', () {
      final p = PromptBuilder.buildMainPrompt(
        soulContext: '',
        userContext: '',
      );
      expect(p, isNot(contains('当前时间')));
    });

    test('currentTimeContext 仍可用（供调用方注入用户消息）', () {
      final s = PromptBuilder.currentTimeContext(DateTime(2026, 7, 9, 13, 44));
      expect(s, contains('2026'));
      expect(s, contains('13:44'));
    });

    test('<role> 使用默认名字（未指定怎么叫我时）', () {
      final p = PromptBuilder.buildMainPrompt(
        soulContext: '',
        userContext: '',
      );
      expect(p, contains('你是 你的 AI 助手，用户的个人 AI 助手'));
    });

    test('<role> 使用用户指定的 AI 名字', () {
      final p = PromptBuilder.buildMainPrompt(
        soulContext: '',
        userContext: '- 怎么叫我：小辣椒\n- 怎么称呼：老大',
      );
      expect(p, contains('你是 小辣椒，用户的个人 AI 助手'));
    });

    test('<role> 占位符时使用默认名', () {
      final p = PromptBuilder.buildMainPrompt(
        soulContext: '',
        userContext: '- 怎么叫我：（待用户首次指定）',
      );
      expect(p, contains('你是 你的 AI 助手，用户的个人 AI 助手'));
    });
  });
}
