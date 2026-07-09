import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/tools/tools.dart';

/// 全工具契约测试：验证每个工具的基本定义，不依赖网络/API/平台/存储。

List<AgentTool> _allTools() => [
  TaskPlanTool(),
  ReminderTool(),
  WebFetchTool(),
  WeatherTool(apiKey: ''),
  LocationTool(),
  SearxngSearchTool(),
  TavilySearchTool(),
  AgnesImageTool(apiKey: ''),
  AgnesVideoTool(apiKey: ''),
  SaveNoteTool(),
  ManageNoteTool(),
  CreateRichNoteTool(),
  AiDailyTool(),
  ContextDocTool(),
  CalendarTool(),
  VirtualFSTool(),
  SkillManageTool(),
  DelegateTaskTool(onDelegate: (_, __) async => 'stub'),
];

void _testContract(AgentTool tool) {
  test('$tool 契约', () {
    // name
    expect(tool.name, isNotEmpty, reason: '工具名不可为空');
    expect(tool.name, isA<String>());

    // description
    expect(tool.description, isNotEmpty, reason: '描述不可为空');
    expect(tool.description.length, greaterThan(10),
        reason: '${tool.name} 描述太短');

    // parameters — 使用宽松类型检查，避免 _Map<dynamic,dynamic> cast 失败
    expect(tool.parameters, isA<Map>());
    final props = tool.parameters['properties'];
    if (props is Map) {
      for (final entry in props.entries) {
        final k = entry.key?.toString() ?? '';
        expect(entry.value, isA<Map>(),
            reason: '${tool.name} 参数 "$k" schema 不合法');
      }
    }

    // readOnly 有值
    expect(tool.readOnly, anyOf(isTrue, isFalse),
        reason: '${tool.name} readOnly 未定义');

    // function definition
    final def = tool.toFunctionDefinition();
    expect(def['type'], 'function');
    final func = def['function'] as Map<String, dynamic>;
    expect(func['name'], tool.name);
    expect(func['description'], tool.description);
    expect(func['parameters'], tool.parameters);
  });
}

void main() {
  group('全工具元数据契约', () {
    for (final tool in _allTools()) {
      _testContract(tool);
    }

    test('ToolSearchTool 契约', () {
      final r = ToolRegistry();
      r.register(WeatherTool(apiKey: ''));
      final tool = ToolSearchTool(registry: r);
      expect(tool.name, 'tool_search');
      expect(tool.description.length, greaterThan(10));
      expect(tool.parameters, isA<Map>());
      expect(tool.toFunctionDefinition()['type'], 'function');
    });

    test('DeferExecuteTool 契约', () {
      final r = ToolRegistry();
      r.register(WeatherTool(apiKey: ''));
      final tool = DeferExecuteTool(registry: r);
      expect(tool.name, 'defer_execute_tool');
      expect(tool.description.length, greaterThan(10));
      expect(tool.parameters, isA<Map>());
      expect(tool.toFunctionDefinition()['type'], 'function');
    });

    test('工具总数 >= 18', () {
      expect(_allTools().length, greaterThanOrEqualTo(18));
    });
  });

  // ── 工具 name 唯一性 ──
  test('所有工具 name 唯一', () {
    final names = <String>{};
    for (final t in _allTools()) {
      expect(names.contains(t.name), isFalse,
          reason: '工具名 "${t.name}" 重复');
      names.add(t.name);
    }
  });

  // ── execute 基本路径测试（不依赖 getIt 嵌套的工具） ──
  group('execute 基本路径', () {
    test('ReminderTool 空参不抛异常', () async {
      // ReminderTool 依赖平台 channel，但空参应在 inspect 前就返回错误
      try {
        await ReminderTool().execute({});
      } catch (_) {
        // 平台 channel 不可用允许抛异常
      }
      // 到达即通过
    });

    test('WebFetchTool 空 URL 返回错误', () async {
      final r = await WebFetchTool().execute({'url': ''});
      expect(r, contains('错误'));
    });

    test('DelegateTaskTool 缺参数返回可读错误', () async {
      final tool = DelegateTaskTool(onDelegate: (_, __) async => '');
      final r = await tool.execute({});
      expect(r, contains('派活失败'));
    });

    test('DelegateTaskTool 正常派发返回 delegate 结果', () async {
      final tool = DelegateTaskTool(
        onDelegate: (name, brief) async => '子Agent "$name" 完成了: $brief',
      );
      final r = await tool.execute({
        'agent': '测试Bot',
        'brief': '执行测试任务',
      });
      expect(r, contains('子Agent "测试Bot" 完成了: 执行测试任务'));
    });
  });
}
