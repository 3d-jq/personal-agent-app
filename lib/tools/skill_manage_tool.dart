import '../core/service_locator.dart';
import 'base_tool.dart';
import 'skill_registry.dart';
import 'skill_manage_tool.g.dart';

/// 技能管理工具：让 Agent 发现、激活、停用技能包
class SkillManageTool extends AgentTool {
  @override
  String get name => 'skill_manage';

  @override
  bool get readOnly => false;

  @override
  String get description => skillManageToolDescription;

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['list', 'activate', 'deactivate', 'match'],
        'description': '操作类型',
      },
      'skill_id': {
        'type': 'string',
        'description': '技能ID（activate/deactivate 时必填）',
      },
      'text': {'type': 'string', 'description': '用户输入文本（match 时使用）'},
    },
    'required': ['action'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String?;
    if (action == null) return '错误: 必须提供 action 参数';

    final registry = getIt<SkillRegistry>();

    switch (action) {
      case 'list':
        final skills = registry.all;
        if (skills.isEmpty) return '暂无可用 Skill';
        final buf = StringBuffer();
        for (final skill in skills) {
          buf.writeln('• ${skill.name}: ${skill.description}');
        }
        return buf.toString();

      case 'activate':
        final skillId = args['skill_id'] as String?;
        if (skillId == null) return '错误: activate 需要提供 skill_id';

        final skill = registry.all.where((s) => s.id == skillId).firstOrNull;
        if (skill == null) return '错误: 找不到技能 "$skillId"';

        if (registry.isActive(skillId)) {
          return '技能「${skill.name}」已经处于激活状态。';
        }

        registry.activate(skillId);
        return '已激活技能「${skill.name}」\n'
            '描述: ${skill.description}\n'
            '已加载对应的指令内容。';

      case 'deactivate':
        final skillId = args['skill_id'] as String?;
        if (skillId == null) return '错误: deactivate 需要提供 skill_id';

        if (!registry.isActive(skillId)) {
          return '技能 "$skillId" 未激活。';
        }

        registry.deactivate(skillId);
        return '已停用技能 "$skillId"。';

      case 'match':
        final text = args['text'] as String?;
        if (text == null) return '错误: match 需要提供 text';

        final matched = registry.matchByKeywords(text);
        if (matched.isEmpty) return '未找到匹配的 Skill';
        final buf = StringBuffer();
        for (final skill in matched) {
          buf.writeln('• ${skill.name}: ${skill.description}');
        }
        return buf.toString();

      default:
        return '错误: 未知操作类型 "$action"';
    }
  }
}
