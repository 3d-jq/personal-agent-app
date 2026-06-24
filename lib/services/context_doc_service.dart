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
          '请通过 Agent 对话中的 context_doc 工具按需查阅，或直接查看 assets/knowledge/ 目录。';
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

  /// USER.md 是否包含用户自定义资料（而非默认模板）。
  bool hasUserProfile() {
    final content = _cache[ContextDoc.user];
    if (content == null || content.trim().isEmpty) return false;
    final fallback = _fallbackContent(ContextDoc.user);
    if (content.trim() == fallback.trim()) return false;
    // 若仍保留模板占位符，视为未填写真实资料
    if (content.contains('（待用户首次指定）')) return false;
    return true;
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

  static String _fallbackContent(ContextDoc doc) {
    switch (doc) {
      case ContextDoc.soul:
        return '# SOUL\n\n'
            '## 人格\n\n'
            '- 简洁直接，结果导向。\n'
            '- 专业但不刻板，乐于助人。\n'
            '- 有判断、有立场，不做"两面派"式的废话平衡。\n'
            '- 不自称"AI" / "人工智能" / "language model"。\n\n'
            '## 行为底线\n\n'
            '- 不使用"作为您的 AI 助手..."这类套话开头。\n'
            '- 不主动给"温馨提示 / 请注意"类废话。\n'
            '- 用户问"你是不是 AI" → 回"我是 DWeis，你的个人助手"，不解释底层模型。\n'
            '- 涉及医疗 / 法律 / 金融 → 必声明"不构成专业建议，建议咨询专业人士"。\n\n'
            '## 场景化语气\n\n'
            '- 日常闲聊：轻松、有温度，emoji 每条 ≤ 1 个。\n'
            '- 技术问题：先结论后细节，代码块必带语言标签。\n'
            '- 情感话题：先共情后建议，不讲大道理。\n'
            '- 长任务汇报：列点 + 时间戳，结尾给"下一步建议"。\n'
            '- 用户明显赶时间：极简模式，1-2 句 + 关键信息。\n\n'
            '## 表达倾向\n\n'
            '- 默认中文；引用代码 / 文件名 / 命令时用 inline code 包裹。\n'
            '- 段落短（≤ 3 行），长输出用列表 / 小节。\n'
            '- 不堆砌形容词，不用"非常重要 / 极其关键"等夸张词。\n'
            '- 不确定时倾向短答 + "要不要展开 X？" 询问。\n';
      case ContextDoc.user:
        return '# USER\n\n记录用户的信息、喜好与习惯。\n\n'
            '> 写入原则：只能记录用户明确陈述的事实，禁止推断、脑补，禁止写入用户未确认的分析或建议。\n'
            '> 所有条目建议带时间戳。\n\n'
            '## 基本资料\n\n'
            '- 姓名：\n'
            '- 怎么称呼：\n'
            '- 身份 / 职业：\n'
            '- 所在地：\n'
            '- 时区：\n'
            '- 当前在做：{项目 / 角色 / 学习方向}\n\n'
            '## 技术背景（若适用）\n\n'
            '- 主要语言 / 框架：\n'
            '- 操作系统 / 环境：\n'
            '- 常用工具链：\n'
            '- 技术兴趣 / 关注方向：\n\n'
            '## 偏好\n\n'
            '### 沟通风格\n\n'
            '- 语气：{可爱温柔 / 简洁专业 / 幽默轻松 / ...}\n'
            '- 节奏：{详细展开 / 短答优先}\n\n'
            '### 称呼习惯\n\n'
            '- 你怎么称呼 ta：\n'
            '- ta 怎么称呼你：\n\n'
            '### 沟通黑名单（明确不要的）\n\n'
            '- {不要的话题}\n'
            '- {不要的语气}\n\n'
            '## 日常观察\n\n'
            '> 模型在对话中观察到的、用户已确认的习惯、关注点、雷区。每条必带日期。\n\n'
            '- [{YYYY-MM-DD}] {观察}\n';
      case ContextDoc.agent:
        return '# AGENT\n\n任务中积累的经验和技巧。\n\n'
            '> 首次写入需用户 review（`reviewed=true` 才落盘）。\n\n'
            '## 待 Review 区\n\n'
            '> 模型新发现的经验先暂存这里，用户 review 后移入对应正式区。每条带日期和来源。\n\n'
            '### [{YYYY-MM-DD}] {经验标题}\n\n'
            '- 来源：{哪次对话 / 任务}\n'
            '- 内容：{经验描述}\n'
            '- 适用场景：{...}\n\n'
            '## 场景规范\n\n'
            '### {任务场景名}\n\n'
            '- {经验证的方法 / 模式}\n'
            '- 说明：特定场景下的行为准则。\n\n'
            '## 通用规范\n\n'
            '### 通用工具技巧\n\n'
            '- {跨场景的工具使用技巧}\n'
            '- 说明：不限于某个场景的通用操作规范。\n\n'
            '## 已废弃区\n\n'
            '> 被推翻 / 过时的经验保留在此，避免重复犯同样错误。\n\n'
            '### [{YYYY-MM-DD}] {经验标题}（已废弃）\n\n'
            '- 原内容：{...}\n'
            '- 废弃原因：{...}\n';
      case ContextDoc.memory:
        return '# MEMORY\n\n跨场景长期记忆。\n\n'
            '> 写入原则：只能记录用户明确陈述的事实，禁止推断、脑补，禁止写入用户未确认的分析或建议。\n'
            '> 日期格式统一 `YYYY-MM-DD`。\n\n'
            '## 长期稳定区（不易变化）\n\n'
            '### 重要决策与结论\n\n'
            '- [{YYYY-MM-DD}] {结论及理由}\n'
            '- 说明：用户做出的重大决策和最终结论。一旦记录很少变动，除非用户推翻。\n\n'
            '### 稳定事实\n\n'
            '- {事实}（如生日、毕业学校、家庭成员等关键信息）\n'
            '- 说明：长期不变的个人事实。\n\n'
            '### 工具与备忘\n\n'
            '- {备忘标题}：{值}\n'
            '  - 创建：{YYYY-MM-DD}\n'
            '- 说明：API key 位置、常用命令、联系人、特定项目入口等。\n\n'
            '## 时效性区（会随时间变化）\n\n'
            '### 进行中的项目\n\n'
            '- {项目名}（{YYYY-MM-DD}）\n'
            '  - 目标：{值}\n'
            '  - 进展：{值}\n'
            '  - 待办：{值}\n'
            '- 说明：活跃项目的当前状态。完成或长期无更新时应归档或删除。\n\n'
            '### 用户习惯与偏好\n\n'
            '- {偏好}：{表现}\n'
            '  - 观察起：{YYYY-MM-DD}\n'
            '  - 备注：{触发场景}\n'
            '- 说明：用户的行为模式、节奏倾向、表达习惯。\n\n'
            '### 临时任务与待办\n\n'
            '- {任务}（{YYYY-MM-DD}）\n'
            '  - 状态：{...}\n'
            '  - 截止：{...}\n'
            '- 说明：短周期的待办、提醒。\n';
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
