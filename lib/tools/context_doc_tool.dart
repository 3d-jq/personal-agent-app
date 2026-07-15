import '../core/service_locator.dart';
import '../services/context_doc_service.dart';
import 'base_tool.dart';
import 'context_doc_read_tool.g.dart';
import 'context_doc_update_tool.g.dart';

/// 读取或更新 Markdown 上下文文档。
///
/// 原 `context_doc`（带 action 参数）已拆分为 2 个独立工具，各自独占调用配额：
/// - [ContextDocReadTool]   读取 SOUL/USER/AGENT/MEMORY/knowledge 文档
/// - [ContextDocUpdateTool] 覆盖写入上述文档
///
/// 文档类型：soul=人格与说话风格；user=用户信息/喜好/习惯；
/// agent=任务中积累的经验与技巧（写入前需 review 确认，避免覆盖 SOUL 人格）；
/// memory=跨场景长期记忆；knowledge=知识库（需 filename）。
abstract class _ContextDocBase extends AgentTool {
  ContextDoc _parseDoc(String value) {
    return ContextDoc.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('未知文档类型: $value'),
    );
  }

  @override
  bool get readOnly => false;

  Future<String> read(Map<String, dynamic> args) async {
    final docRaw = (args['doc'] as String?)?.trim();
    if (docRaw == null || docRaw.isEmpty) {
      return '错误：必须提供 doc 参数。';
    }
    final doc = _parseDoc(docRaw);
    final service = getIt<ContextDocService>();

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
  }

  Future<String> update(Map<String, dynamic> args) async {
    final docRaw = (args['doc'] as String?)?.trim();
    if (docRaw == null || docRaw.isEmpty) {
      return '错误：必须提供 doc 参数。';
    }
    final doc = _parseDoc(docRaw);
    final content = args['content'] as String?;
    if (content == null) {
      return '错误：update 操作需要提供 content 参数。';
    }
    final reviewed = (args['reviewed'] as bool?) ?? false;

    final service = getIt<ContextDocService>();
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
  }
}

/// 标记 USER.md 首次见面流程已完成。
/// 调用后 `state: completed`，不再触发首次见面引导。
class ContextDocCompleteTool extends AgentTool {
  @override
  String get name => 'context_doc_complete';
  @override
  String get description => '标记 USER.md 首次见面引导已完成。'
      '调用后 state 变为 completed，此引导不再出现。'
      '仅在首次见面对话末尾（用户已告诉你称呼/风格/给你起名后）调用。';
  @override
  bool get readOnly => false;

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'doc': {
        'type': 'string',
        'enum': ['user'],
        'description': '固定传 "user"，标记 USER.md 完成',
      },
    },
    'required': ['doc'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final docRaw = (args['doc'] as String?)?.trim() ?? 'user';
    if (docRaw != 'user') return '错误：context_doc_complete 仅支持 doc="user"';
    try {
      await getIt<ContextDocService>().markProfileComplete();
      return '首次见面已完成！USER.md 已标记为 completed，后续对话不再触发首次见面引导。';
    } on Exception catch (e) {
      return '标记失败：$e';
    }
  }
}

/// 读取上下文文档（SOUL/USER/AGENT/MEMORY/knowledge）。
class ContextDocReadTool extends _ContextDocBase {
  @override
  String get name => 'context_doc_read';
  @override
  String get description => contextDocReadToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'doc': {
        'type': 'string',
        'enum': ['soul', 'user', 'agent', 'memory', 'knowledge'],
        'description': '文档类型：soul / user / agent / memory / knowledge',
      },
      'filename': {
        'type': 'string',
        'description': '仅 knowledge 类型需要：知识库文件名，如 01_major_selection.md',
      },
    },
    'required': ['doc'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      return await read(args);
    } catch (e) {
      return '错误：$e';
    }
  }
}

/// 覆盖写入上下文文档。
class ContextDocUpdateTool extends _ContextDocBase {
  @override
  String get name => 'context_doc_update';
  @override
  String get description => contextDocUpdateToolDescription;
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
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
        'description': '要写入的 Markdown 内容',
      },
      'reviewed': {'type': 'boolean', 'description': '仅对 agent 文档有效'},
    },
    'required': ['doc', 'content'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      return await update(args);
    } catch (e) {
      return '错误：$e';
    }
  }
}
