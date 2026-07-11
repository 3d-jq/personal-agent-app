import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 上下文文档类型。
enum ContextDoc {
  soul('SOUL.md'),
  user('USER.md'),
  agent('AGENT.md'),
  memory('MEMORY.md'),
  knowledge(''); // 特殊类型，文件名通过参数传入

  final String fileName;
  const ContextDoc(this.fileName);
}

/// Markdown 上下文文档服务。
///
/// 负责 SOUL.md / USER.md / AGENT.md / MEMORY.md 的读取、写入、缺省初始化。
/// - 不自动把 AGENT.md / MEMORY.md 注入系统提示，避免污染上下文。
/// - AGENT.md 写入需要 review 确认，防止覆盖人格设定。
class ContextDocService {
  ContextDocService();

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
      if (doc == ContextDoc.knowledge) continue; // 知识库文件单独处理
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
      if (doc == ContextDoc.knowledge) continue;
      await read(doc);
    }
  }

  /// 读取指定文档内容。优先读内存缓存，未缓存则从文件读取。
  Future<String> read(ContextDoc doc) async {
    // knowledge 不是单个文件，由 readKnowledge 按需读取
    if (doc == ContextDoc.knowledge) {
      return '知识库包含 8 个文件（00_ai_era_correction.md ~ 07_new_gaokao_subject_selection.md），'
          '请通过 Agent 对话中的 context_doc_read 工具按需查阅，或直接查看 assets/knowledge/ 目录。';
    }
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

  /// USER.md 是否包含有效用户资料（而非默认模板）。
  ///
  /// 完成判定走「哨兵」思路（对标 BOOTSTRAP.md 的 file-gate）：
  /// 模板自带占位符「（待用户首次指定）」，存在即视为未完成；
  /// 移除占位符且「怎么称呼」已填实才算完成。
  /// 不依赖具体中文字段名（如「语气风格」），避免模板字段微调导致误判。
  bool hasUserProfile() => isProfileContentComplete(_cache[ContextDoc.user]);

  /// 纯函数版，便于测试。判定逻辑见 [hasUserProfile]。
  static bool isProfileContentComplete(String? content) {
    if (content == null || content.trim().isEmpty) return false;
    // 哨兵：模板占位符仍在 → 未完成（任一字段留占位都算未完成）
    if (content.contains('（待用户首次指定）')) return false;
    final fallback = _fallbackContent(ContextDoc.user);
    if (content.trim() == fallback.trim()) return false;
    // 关键字段「怎么称呼」已填实（后面跟了非占位的实际内容）
    final nameFilled =
        RegExp(r'怎么称呼：\s*(?!（待用户首次指定）)\S').hasMatch(content);
    return nameFilled;
  }

  /// 读取指定知识库文件。返回完整 Markdown 内容。
  Future<String> readKnowledge(String filename) async {
    // 清理文件名防注入
    final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '');
    if (safe.isEmpty) throw ArgumentError('无效的文件名: $filename');

    try {
      return await rootBundle.loadString('assets/knowledge/$safe');
    } catch (_) {
      throw ArgumentError('知识库文件不存在: $safe。可用列表见 prompt。');
    }
  }

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

  /// 追加文档内容。
  ///
  /// 用于新增记忆/偏好/经验，避免模型为了保留旧内容而 read → update 整篇文档。
  Future<void> append(
    ContextDoc doc,
    String content, {
    bool reviewed = false,
  }) async {
    if (doc == ContextDoc.knowledge) {
      throw ArgumentError('knowledge 文档只读，不支持 append');
    }
    if (doc == ContextDoc.soul) {
      throw ArgumentError('SOUL.md 不支持 append，请由用户直接编辑或使用 update 覆盖写入');
    }
    if (doc == ContextDoc.agent && !reviewed) {
      throw ContextDocReviewRequiredException(
        '修改 AGENT.md 前需要确认：请检查本次追加不会覆盖 SOUL.md 中的人格设定。'
        '确认后请再次调用并设置 reviewed=true。',
      );
    }

    final current = await read(doc);
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final next = current.trimRight().isEmpty
        ? '$trimmed\n'
        : '${current.trimRight()}\n\n$trimmed\n';
    final file = await _file(doc);
    await file.writeAsString(next);
    _cache[doc] = next;
  }

  static String _fallbackContent(ContextDoc doc) {
    switch (doc) {
      case ContextDoc.soul:
        return '# SOUL.md\n'
            'AI 说话、做事的专属风格\n\n'
            '---\n\n'
            '## 你的人设\n'
            '在对话中把它补齐，让它变成你的设定。\n\n'
            '- 名称：你的 AI 助手\n'
            '- 角色：用户的个人 AI 助手\n'
            '- 风格：简洁直接，结果导向\n'
            '- 语气：专业但不刻板，乐于助人\n'
            '- 特殊要求：不要自称"AI"\n\n'
            '---\n\n'
            '这不只是配置项。这是你开始搞清楚"你是谁"的起点。\n';
      case ContextDoc.user:
        return '# USER.md\n'
            '记录你的信息、喜好、习惯等\n\n'
            '---\n\n'
            '## 关于用户\n'
            '认识你正在帮助的这个人。边认识边更新。\n\n'
            '- 姓名：\n'
            '- 怎么称呼：（待用户首次指定）\n'
            '- 怎么叫我：（待用户首次指定）\n'
            '- 身份：\n'
            '- 所在地：\n'
            '- 备注：\n\n'
            '## 更多了解\n\n'
            '（ta 在乎什么？在做什么项目？什么事会烦到 ta？什么事会逗 ta 笑？慢慢把这部分攒起来。）\n\n'
            '---\n\n'
            '知道得越多，帮助得越到位。但要记得——你在认识一个人，不是在建档案。\n';
      case ContextDoc.agent:
        return '# AGENT.md\n'
            '任务中积累的经验和技巧\n\n'
            '---\n\n'
            '## 场景规范（针对具体任务场景的操作规则）\n\n'
            '### {任务场景名}\n\n'
            '- {经验证的方法/模式}\n'
            '  说明：特定场景下的行为准则。\n\n'
            '## 通用规范（跨场景的通用规则）\n\n'
            '### 通用工具技巧\n\n'
            '- {跨场景的工具使用技巧}\n'
            '  说明：不限于某个场景的通用操作规范。\n';
      case ContextDoc.memory:
        return '# MEMORY\n\n'
            '跨场景长期记忆。\n\n'
            '> 写入原则：只能记录用户明确说出来的事实，禁止推断、脑补，禁止写入用户未确认的分析或建议。\n'
            '> 以下均为空模板，内容由模型在对话中逐步记录，禁止预填默认值。\n\n'
            '## 长期稳定区\n\n'
            '不易变化、持久有效，优先保留。\n\n'
            '### 重要结论与决策\n\n'
            '- [{日期}] {结论及理由}\n'
            '- 说明：用户做出的重大决策和最终结论。一旦记录很少变动，除非用户推翻。\n\n'
            '## 时效性区\n\n'
            '随时间变化，定期更新或淘汰，超限时优先删除。\n\n'
            '### 进行中的项目\n\n'
            '- {项目名}（{日期}）\n'
            '  - 目标：{值}\n'
            '  - 进展：{值}\n'
            '  - 待办：{值}\n'
            '- 说明：活跃项目的当前状态。项目完成或长期无更新时应归档或删除。\n';
      case ContextDoc.knowledge:
        return ''; // 知识库文件不通过 _fallbackContent 兜底
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
