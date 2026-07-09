import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/prompt_builder.dart';

void main() {
  final now = DateTime(2026, 7, 9, 13, 44);

  group('PromptBuilder.buildMainPrompt 记忆规则', () {
    test('包含 USER.md 维护指引（规则 9）', () {
      final p = PromptBuilder.buildMainPrompt(
        now: now,
        soulContext: '',
        userContext: '',
      );
      expect(p, contains('USER.md'));
      expect(p, contains('context_doc'));
    });

    test('包含 MEMORY.md 维护指引（规则 11：跨会话事实持久化）', () {
      final p = PromptBuilder.buildMainPrompt(
        now: now,
        soulContext: '',
        userContext: '',
      );
      expect(p, contains('MEMORY.md'));
      expect(p, contains('跨会话'));
      expect(p, contains('禁止推断脑补'));
    });

    test('包含 AGENT.md 维护指引（规则 12：任务经验沉淀，需 reviewed=true）', () {
      final p = PromptBuilder.buildMainPrompt(
        now: now,
        soulContext: '',
        userContext: '',
      );
      expect(p, contains('AGENT.md'));
      expect(p, contains('reviewed=true'));
      expect(p, contains('SOUL.md'));
    });

    test('首次见面分支仍要求写入 USER.md', () {
      final p = PromptBuilder.buildMainPrompt(
        now: now,
        soulContext: '',
        userContext: '',
        isFirstMeeting: true,
        hasExistingProfile: false,
      );
      expect(p, contains('first_meeting'));
      expect(p, contains('context_doc'));
    });

    test('有 persona/user_profile 时注入人格一致性硬约束（对抗人格漂移）', () {
      final p = PromptBuilder.buildMainPrompt(
        now: now,
        soulContext: '# SOUL\n语气：可爱温柔',
        userContext: '# USER\n怎么称呼：小张',
      );
      expect(p, contains('persona_constraints'));
      expect(p, contains('人格一致性'));
      expect(p, contains('始终以 <persona>'));
      expect(p, contains('怎么称呼'));
      expect(p, contains('最高优先级'));
    });

    test('空 persona/user_profile 时不注入人格一致性约束', () {
      final p = PromptBuilder.buildMainPrompt(
        now: now,
        soulContext: '',
        userContext: '',
      );
      expect(p, isNot(contains('persona_constraints')));
    });
  });
}
