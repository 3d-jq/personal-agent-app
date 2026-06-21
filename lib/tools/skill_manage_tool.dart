import 'base_tool.dart';
import 'skill_registry.dart';

/// 技能管理工具：让 Agent 发现、激活、停用技能包
class SkillManageTool extends AgentTool {
  @override
  String get name => 'skill_manage';

  @override
  bool get readOnly => false;

  @override
  String get description => '''
管理 Agent 技能包。技能包是一组相关工具和 prompt 模板的组合。
- list: 查看所有可用技能
- activate: 激活一个技能（加载其工具和 prompt）
- deactivate: 停用一个技能
- match: 根据用户输入自动匹配可能需要的技能
激活技能后，对应的工具和 prompt 模板会自动加载到当前会话中。'''.trim();

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
          'text': {
            'type': 'string',
            'description': '用户输入文本（match 时使用）',
          },
        },
        'required': ['action'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String?;
    if (action == null) return '错误: 必须提供 action 参数';

    final registry = SkillRegistry();

    switch (action) {
      case 'list':
        return registry.listAll();

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
            '包含工具: ${skill.toolNames.join(", ")}\n'
            '已加载对应的 prompt 模板。';

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
        if (matched.isEmpty) return '没有匹配到相关技能。';

        final buf = StringBuffer('【匹配到的技能】\n');
        for (final s in matched) {
          final status = registry.isActive(s.id) ? '✅ 已激活' : '⬜ 未激活';
          buf.writeln('${s.id}: ${s.name} — $status');
          buf.writeln('  ${s.description}');
        }
        buf.writeln('\n建议激活以上技能以获得更好的执行效果。');
        return buf.toString();

      default:
        return '错误: 不支持的操作 "$action"';
    }
  }
}
