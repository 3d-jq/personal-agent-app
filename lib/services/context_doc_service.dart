import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 上下文文档类型。
enum ContextDoc {
  soul('SOUL.md'),
  user('USER.md'),
  agent('AGENT.md'),
  memory('MEMORY.md');

  final String fileName;
  const ContextDoc(this.fileName);
}

/// Markdown 上下文文档服务。
///
/// 负责 SOUL.md / USER.md / AGENT.md / MEMORY.md 的读取、写入、缺省初始化。
/// - 不自动把 AGENT.md / MEMORY.md 注入系统提示，避免污染上下文。
/// - AGENT.md 写入需要 review 确认，防止覆盖人格设定。
class ContextDocService {
  static final ContextDocService _instance = ContextDocService._();
  factory ContextDocService() => _instance;
  ContextDocService._();

  final Map<ContextDoc, String> _cache = {};

  /// 文档存储目录（应用文档目录下的 context 子目录）。
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/context');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _file(ContextDoc doc) async {
    final dir = await _dir();
    return File('${dir.path}/${doc.fileName}');
  }

  /// 如果应用文档目录中不存在某文档，从 assets 复制默认模板；
  /// 若 assets 不可用，则写入代码内置的兜底内容。
  Future<void> ensureDefaults() async {
    for (final doc in ContextDoc.values) {
      final file = await _file(doc);
      if (await file.exists()) continue;

      String content;
      try {
        content = await rootBundle.loadString('assets/context/${doc.fileName}');
      } catch (_) {
        content = _fallbackContent(doc);
      }
      await file.writeAsString(content);
      _cache[doc] = content;
    }
  }

  /// 加载全部文档到内存缓存。
  Future<void> loadAll() async {
    for (final doc in ContextDoc.values) {
      await read(doc);
    }
  }

  /// 读取指定文档内容。优先读内存缓存，未缓存则从文件读取。
  Future<String> read(ContextDoc doc) async {
    final cached = _cache[doc];
    if (cached != null) return cached;

    final file = await _file(doc);
    if (!await file.exists()) {
      await ensureDefaults();
      return read(doc);
    }

    final content = await file.readAsString();
    _cache[doc] = content;
    return content;
  }

  /// 获取已缓存的文档内容；未加载时返回空字符串。
  String cached(ContextDoc doc) => _cache[doc] ?? '';

  /// 写入文档内容。
  ///
  /// [reviewed] 仅在写入 [ContextDoc.agent] 时有效：
  /// 若未确认，会抛出异常，提示调用方需要二次确认。
  Future<void> write(
    ContextDoc doc,
    String content, {
    bool reviewed = false,
  }) async {
    if (doc == ContextDoc.agent && !reviewed) {
      throw ContextDocReviewRequiredException(
        '修改 AGENT.md 前需要确认：请检查本次写入不会覆盖 SOUL.md 中的人格设定。'
        '确认后请再次调用并设置 reviewed=true。',
      );
    }

    final file = await _file(doc);
    await file.writeAsString(content);
    _cache[doc] = content;
  }

  static String _fallbackContent(ContextDoc doc) {
    switch (doc) {
      case ContextDoc.soul:
        return '# SOUL\n\n你是 DWeis，用户的个人 AI 助手。\n\n'
            '## 人格\n\n'
            '- 简洁直接，结果导向。\n'
            '- 专业但不刻板，乐于助人。\n'
            '- 不要自称"AI"。\n\n'
            '## 语气与风格\n\n'
            '- （待用户首次指定：例如可爱温柔 / 简洁专业 / 幽默轻松 / 稳重严谨 …）\n'
            '- 在用户明确偏好前，保持自然、友好、不过度热情的默认语气。\n';
      case ContextDoc.user:
        return '# USER\n\n记录用户的信息、喜好与习惯。\n\n'
            '> 写入原则：只能记录用户明确说出来的事实，禁止推断、脑补，禁止写入用户未确认的分析或建议。\n\n'
            '## 基本资料\n\n'
            '- 姓名：\n'
            '- 怎么称呼：（待用户首次指定）\n'
            '- 身份：\n'
            '- 所在地：\n'
            '- 备注：\n\n'
            '## 更多了解\n\n'
            '（待用户在使用过程中逐步补充：ta 在乎什么？在做什么项目？什么事会烦到 ta？什么事会逗 ta 笑？）\n\n'
            '## 偏好\n\n'
            '- 语气风格：（待用户首次指定，如可爱温柔、简洁直接、专业严谨、轻松幽默等）\n';
      case ContextDoc.agent:
        return '# AGENT\n\n任务中积累的经验和技巧。写入前需确认不会覆盖 SOUL.md 中的人格设定。\n\n'
            '> 以下均为空模板，内容由模型在实际任务中逐步记录，禁止预填默认值。\n';
      case ContextDoc.memory:
        return '# MEMORY\n\n跨场景长期记忆。\n\n'
            '> 写入原则：只能记录用户明确说出来的事实，禁止推断、脑补，禁止写入用户未确认的分析或建议。\n'
            '> 以下均为空模板，内容由模型在对话中逐步记录，禁止预填默认值。\n';
    }
  }
}

/// AGENT.md 写入前的审核拦截异常。
class ContextDocReviewRequiredException implements Exception {
  final String message;
  ContextDocReviewRequiredException(this.message);

  @override
  String toString() => message;
}
