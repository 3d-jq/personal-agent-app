import '../core/service_locator.dart';
import '../services/context_doc_service.dart';
import 'base_tool.dart';
import 'context_doc_tool.g.dart';

/// 读取或更新 Markdown 上下文文档。
///
/// 支持 SOUL.md / USER.md / AGENT.md / MEMORY.md：
/// - SOUL.md：人格与说话风格。
/// - USER.md：用户信息、喜好、习惯。
/// - AGENT.md：任务中积累的经验与技巧；写入前需要 review 确认，避免覆盖 SOUL.md 人格。
/// - MEMORY.md：跨场景长期记忆。
class ContextDocTool extends AgentTool {
  @override
  String get name => 'context_doc';
  @override
  bool get readOnly => false;

  @override
  String get description => contextDocToolDescription;

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['read', 'update'],
        'description': 'read=读取；update=覆盖写入',
      },
      'doc': {
        'type': 'string',
        'enum': ['soul', 'user', 'agent', 'memory', 'knowledge'],
        'description': '文档类型：soul / user / agent / memory / knowledge',
      },
      'filename': {
        'type': 'string',
        'description': '仅 knowledge 类型需要：知识库文件名，如 01_major_selection.md',
      },
      'content': {
        'type': 'string',
        'description': 'update 时使用，覆盖写入的完整 Markdown 内容',
      },
      'reviewed': {'type': 'boolean', 'description': '仅对 agent 文档有效'},
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
    final service = getIt<ContextDocService>();

    switch (action) {
      case 'read':
        if (doc == ContextDoc.knowledge) {
          final filename = (args['filename'] as String?)?.trim();
          if (filename == null || filename.isEmpty) {
            return '错误：读取 knowledge 文档需要提供 filename 参数。'
                '可用文件：00_ai_era_correction.md ～ 07_new_gaokao_subject_selection.md';
          }
          try {
            final content = await service.readKnowledge(filename);
            if (content.trim().isEmpty) return '$filename 当前为空。';
            return '【$filename】\n$content';
          } on ArgumentError catch (e) {
            return e.message.toString();
          }
        }
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
          ContextDoc.knowledge => '知识库',
        };
        return '$label文档（${doc.fileName}）已更新。';

      default:
        return '错误：不支持的操作 "$action"，请使用 read 或 update。';
    }
  }
}
