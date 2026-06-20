import '../services/context_doc_service.dart';
import 'base_tool.dart';

/// 读取或更新 Markdown 上下文文档。
///
/// 支持 SOUL.md / USER.md / AGENT.md / MEMORY.md：
/// - SOUL.md：人格与说话风格。
/// - USER.md：用户信息、喜好、习惯。
/// - AGENT.md：任务中积累的经验与技巧；写入前需要 review 确认，避免覆盖 SOUL.md 人格。
/// - MEMORY.md：跨场景长期记忆。
class ContextDocTool extends AgentTool {
  @override String get name => 'context_doc';
  @override bool get readOnly => false;

  @override
  String get description => '''
读取或更新上下文 Markdown 文档（SOUL.md / USER.md / AGENT.md / MEMORY.md）。
- read：查看指定文档的当前内容。
- update：覆盖写入指定文档的完整内容（必须传入完整 Markdown，不能只传改动部分；建议先 read 再 update）。
注意：
- SOUL.md / USER.md / MEMORY.md 可直接更新，但 update 只能写入用户明确陈述的内容，禁止推断、脑补、添加用户未确认的分析或建议。
- 修改 AGENT.md 前必须先 review：第一次调用会返回确认请求，确认不会覆盖 SOUL.md 人格后，再带 reviewed=true 调用一次才会真正写入。
- AGENT.md 和 MEMORY.md 不会自动加载到系统提示中，需要时请先 read。'''.trim();

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['read', 'update'],
            'description': 'read=读取文档；update=覆盖写入文档',
          },
          'doc': {
            'type': 'string',
            'enum': ['soul', 'user', 'agent', 'memory'],
            'description': '文档类型：soul / user / agent / memory',
          },
          'content': {
            'type': 'string',
            'description': 'update 时使用，覆盖写入的完整 Markdown 内容',
          },
          'reviewed': {
            'type': 'boolean',
            'description': '仅对 agent 文档有效；确认已检查不会覆盖 SOUL.md 人格设定',
          },
        },
        'required': ['action', 'doc'],
      };

  ContextDoc _parseDoc(String value) {
    return ContextDoc.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('未知文档类型: $value'),
    );
  }

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final action = (args['action'] as String?)?.trim();
    final docRaw = (args['doc'] as String?)?.trim();

    if (action == null || action.isEmpty || docRaw == null || docRaw.isEmpty) {
      return '错误：必须提供 action 和 doc 参数。';
    }

    final doc = _parseDoc(docRaw);
    final service = ContextDocService();

    switch (action) {
      case 'read':
        final content = await service.read(doc);
        if (content.trim().isEmpty) {
          return '${doc.fileName} 当前为空。';
        }
        return '【${doc.fileName}】\n$content';

      case 'update':
        final content = args['content'] as String?;
        if (content == null) {
          return '错误：update 操作需要提供 content 参数。';
        }
        final reviewed = (args['reviewed'] as bool?) ?? false;

        try {
          await service.write(doc, content, reviewed: reviewed);
        } on ContextDocReviewRequiredException catch (e) {
          return '$e';
        }

        final label = switch (doc) {
          ContextDoc.soul => '人格',
          ContextDoc.user => '用户资料',
          ContextDoc.agent => '任务经验',
          ContextDoc.memory => '长期记忆',
        };
        return '$label文档（${doc.fileName}）已更新。';

      default:
        return '错误：不支持的操作 "$action"，请使用 read 或 update。';
    }
  }
}
