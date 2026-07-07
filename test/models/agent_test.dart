import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/models/agent.dart';
import 'package:personal_agent_app/models/agent_group.dart';

void main() {
  group('Agent', () {
    test('creates agent with required fields', () {
      final agent = Agent(
        id: 'agent-1',
        name: 'Test Agent',
      );

      expect(agent.id, 'agent-1');
      expect(agent.name, 'Test Agent');
    });

    test('creates agent with optional fields', () {
      final agent = Agent(
        id: 'agent-1',
        name: 'Test Agent',
        avatar: '🤖',
        role: 'A test agent',
        model: 'gpt-4',
        systemPrompt: 'You are a test agent',
      );

      expect(agent.avatar, '🤖');
      expect(agent.role, 'A test agent');
      expect(agent.model, 'gpt-4');
      expect(agent.systemPrompt, 'You are a test agent');
    });

    test('converts to JSON and back', () {
      final agent = Agent(
        id: 'agent-1',
        name: 'Test Agent',
        avatar: '🤖',
        role: 'A test agent',
      );

      final json = agent.toJson();
      final restored = Agent.fromJson(json);

      expect(restored.id, agent.id);
      expect(restored.name, agent.name);
      expect(restored.role, agent.role);
      expect(restored.avatar, agent.avatar);
    });
  });

  group('AgentGroup', () {
    test('creates group with required fields', () {
      final group = AgentGroup(
        id: 'group-1',
        name: 'Test Group',
        agentIds: ['agent-1', 'agent-2'],
      );

      expect(group.id, 'group-1');
      expect(group.name, 'Test Group');
      expect(group.agentIds, ['agent-1', 'agent-2']);
    });

    test('converts to JSON and back', () {
      final group = AgentGroup(
        id: 'group-1',
        name: 'Test Group',
        agentIds: ['agent-1', 'agent-2'],
        description: 'A test group',
      );

      final json = group.toJson();
      final restored = AgentGroup.fromJson(json);

      expect(restored.id, group.id);
      expect(restored.name, group.name);
      expect(restored.agentIds, group.agentIds);
      expect(restored.description, group.description);
    });

    test('agentIds list is accessible', () {
      final group = AgentGroup(
        id: 'group-1',
        name: 'Test Group',
        agentIds: ['agent-1'],
      );

      expect(group.agentIds, ['agent-1']);
      expect(group.agentIds.length, 1);
    });
  });
}
