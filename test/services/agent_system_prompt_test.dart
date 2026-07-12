import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/models/agent.dart';
import 'package:personal_agent_app/services/agent_system_prompt.dart';

void main() {
  group('buildAgentSystemPrompt', () {
    test('单聊：注入身份/角色，并声明一对一对话（不含群成员列表）', () {
      final agent = Agent(id: 'a', name: '小智', role: '全能助手');
      final prompt = buildAgentSystemPrompt(
        agent,
        memberNames: const ['小智'],
        memberRoles: const {'小智': '全能助手'},
        isGroupChat: false,
      );
      expect(prompt, contains('小智'));
      expect(prompt, contains('全能助手'));
      expect(prompt, contains('一对一对话'));
      expect(prompt, isNot(contains('delegate_task')));
    });

    test('群聊协调者：包含群名/描述/成员，并给出 delegate_task 派活规则', () {
      final coord = Agent(
        id: 'c',
        name: 'DWeis',
        role: '协调者',
        isCoordinator: true,
      );
      final prompt = buildAgentSystemPrompt(
        coord,
        memberNames: const ['DWeis', '子Bot'],
        memberRoles: const {'DWeis': '协调者', '子Bot': '测试助手'},
        isGroupChat: true,
        groupName: '测试群',
        groupDesc: '一个测试项目群',
      );
      expect(prompt, contains('测试群'));
      expect(prompt, contains('一个测试项目群'));
      expect(prompt, contains('子Bot'));
      expect(prompt, contains('delegate_task'));
      expect(prompt, contains('协调者'));
    });

    test('群聊子 Agent：提示其为子 Agent，不可反向派活', () {
      final child = Agent(
        id: 'x',
        name: '子Bot',
        role: '测试助手',
        isCoordinator: false,
      );
      final prompt = buildAgentSystemPrompt(
        child,
        memberNames: const ['DWeis', '子Bot'],
        memberRoles: const {'DWeis': '协调者', '子Bot': '测试助手'},
        isGroupChat: true,
        groupName: '测试群',
      );
      expect(prompt, contains('子 Agent'));
      expect(prompt, isNot(contains('你是群聊的「主 Agent（协调者）')));
    });

    test('有 systemPrompt 时注入 <persona> 人设段落', () {
      final agent = Agent(
        id: 'a',
        name: '小智',
        role: '助手',
        systemPrompt: '你说话很简洁。',
      );
      final prompt = buildAgentSystemPrompt(
        agent,
        memberNames: const ['小智'],
        memberRoles: const {'小智': '助手'},
        isGroupChat: false,
      );
      expect(prompt, contains('<persona>'));
      expect(prompt, contains('你说话很简洁。'));
    });
  });
}
