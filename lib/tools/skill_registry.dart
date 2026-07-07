import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/skill.dart';
import '../services/log_service.dart';

/// 技能注册表
///
/// 管理所有已发现的 Skill。所有注册的 Skill 默认全部激活，
/// 无需手动开关。
///
/// 采用渐进式披露架构：
/// - 第1层 frontmatter（始终注入 prompt）：name + description
/// - 第2层 SKILL.md 正文（AI 按需读取）：概述 + 指令
/// - 第3层 cookbook/*.md（AI 按需读取）：详细操作步骤
///
/// 存储格式为目录结构：
/// ```
/// skills/{name}/
///   ├── SKILL.md          # frontmatter + 正文
///   └── cookbook/          # 可选
///       ├── step1.md
///       └── step2.md
/// ```
class SkillRegistry {
  SkillRegistry();

  final Map<String, Skill> _skills = {};

  bool _loaded = false;

  /// 注册 Skill
  void register(Skill skill) {
    _skills[skill.id] = skill;
  }

  /// 注册内置 Skill
  void registerBuiltInSkills() {
    // create-skill: 让大模型在对话中创建自定义 Skill
    register(Skill(
      id: 'create-skill',
      name: 'create-skill',
      description: '创建自定义 Skill。当用户想要创建新的 Skill 时使用此工具。',
      instructions: '''当用户想要创建新的 Skill 时：

1. 询问用户 Skill 的名称
2. 询问 Skill 的描述（应说明什么情况下使用这个 Skill）
3. 询问 Skill 的指令内容（AI 在什么情况下使用这个 Skill，执行什么步骤，用哪些工具）
4. 询问 Skill 的触发关键词（可选，用逗号分隔）
5. 调用 skill_manage 工具创建技能：
   skill_manage(action="create", name="<名称>", description="<描述>", instructions="<指令内容>", keywords=["关键词1", "关键词2"])
6. 告诉用户 Skill 已创建

创建 Skill 时，指令应该清晰描述：
- 什么情况下激活这个 Skill
- Skill 需要执行什么步骤
- 使用哪些工具

创建后技能自动生效并持久化到磁盘，重启后仍然可用。''',
      keywords: ['创建skill', '新建skill', '自定义skill', '添加skill'],
    ));
  }

  /// 获取所有已注册 Skill
  List<Skill> get all => List.unmodifiable(_skills.values);

  /// 获取所有激活的 Skill（全部默认激活）
  List<Skill> get active => all;

  /// 根据关键词匹配可能需要的 Skill
  List<Skill> matchByKeywords(String text) {
    final lower = text.toLowerCase();
    return _skills.values.where((s) {
      return s.keywords.any((kw) => lower.contains(kw.toLowerCase()));
    }).toList();
  }

  /// 获取 Skill 目录（用于注入到 system prompt）
  ///
  /// 只注入第1层：name + description（渐进式披露）
  /// AI 需要正文时通过 skill_manage(action=read) 按需读取
  String getCatalog() {
    if (_skills.isEmpty) return '';

    final buf = StringBuffer();
    buf.writeln('<available_skills>');
    for (final skill in _skills.values) {
      buf.writeln('  <skill>');
      buf.writeln('    <name>${skill.name}</name>');
      buf.writeln('    <description>${skill.description}</description>');
      if (skill.cookbookFiles.isNotEmpty) {
        buf.writeln('    <cookbook>${skill.cookbookFiles.join(', ')}</cookbook>');
      }
      buf.writeln('  </skill>');
    }
    buf.writeln('</available_skills>');
    return buf.toString();
  }

  /// 读取某个 Skill 的正文（第2层）
  String getInstructions(String skillId) {
    final skill = _skills[skillId];
    if (skill == null) return '错误: 找不到技能 "$skillId"';
    return skill.instructions;
  }

  /// 读取某个 Skill 的 cookbook 文件内容（第3层）
  Future<String> getCookbookContent(String skillId, String fileName) async {
    final skill = _skills[skillId];
    if (skill == null) return '错误: 找不到技能 "$skillId"';
    if (!skill.cookbookFiles.contains(fileName)) {
      return '错误: 技能 "$skillId" 没有 cookbook 文件 "$fileName"。可用文件：${skill.cookbookFiles.join(", ")}';
    }
    try {
      final dir = await _skillDir();
      final file = File('${dir.path}/${skill.id}/cookbook/$fileName');
      if (file.existsSync()) return file.readAsStringSync();
      return '错误: cookbook 文件 "$fileName" 不存在';
    } catch (e) {
      return '错误: 读取 cookbook 失败: $e';
    }
  }

  // ═══ 持久化（目录结构 + SKILL.md 格式） ═══

  /// Skill 存储根目录
  Future<Directory> _skillDir() async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory('${doc.path}/skills');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// 启动时从磁盘加载自定义 Skill。
  /// 内置 Skill 不落盘，由 [registerBuiltInSkills] 注册。
  ///
  /// 兼容旧格式：如果发现旧的 {id}.json 文件，自动迁移为目录结构。
  Future<void> loadFromDisk() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final dir = await _skillDir();

      for (final entry in dir.listSync()) {
        if (entry is Directory) {
          // 新格式：目录结构 skills/{name}/SKILL.md
          final skillMd = File('${entry.path}/SKILL.md');
          if (skillMd.existsSync()) {
            try {
              final content = skillMd.readAsStringSync();
              final name = entry.path.split(Platform.pathSeparator).last;
              final skill = Skill.fromMarkdown(name, content, location: skillMd.path);
              // 扫描 cookbook 文件
              final cookbookDir = Directory('${entry.path}/cookbook');
              if (cookbookDir.existsSync()) {
                final cookbookFiles = cookbookDir
                    .listSync()
                    .whereType<File>()
                    .where((f) => f.path.endsWith('.md'))
                    .map((f) => f.path.split(Platform.pathSeparator).last)
                    .toList();
                if (cookbookFiles.isNotEmpty) {
                  register(skill.copyWith(cookbookFiles: cookbookFiles));
                  continue;
                }
              }
              register(skill);
            } catch (e) {
              log.w('SkillRegistry', '加载技能 ${entry.path} 失败: $e');
            }
          }
        } else if (entry is File && entry.path.endsWith('.json')) {
          // 旧格式兼容：{id}.json → 自动迁移为目录结构
          try {
            final json = jsonDecode(entry.readAsStringSync()) as Map<String, dynamic>;
            final skill = Skill.fromJson(json);
            if (!_skills.containsKey(skill.id)) {
              // 迁移到新格式
              await persistSkill(skill);
              register(skill);
            }
            // 删除旧 JSON 文件
            entry.deleteSync();
          } catch (e) {
            log.w('SkillRegistry', '迁移旧技能JSON失败: $e');
          }
        }
      }
    } catch (e) {
      log.e('SkillRegistry', '从磁盘加载技能失败: $e');
    }
  }

  /// 持久化一个自定义 Skill 到磁盘（目录结构 + SKILL.md 格式）
  Future<void> persistSkill(Skill skill) async {
    try {
      final dir = await _skillDir();
      final skillDir = Directory('${dir.path}/${skill.id}');
      if (!skillDir.existsSync()) skillDir.createSync(recursive: true);

      // 写入 SKILL.md
      final skillMd = File('${skillDir.path}/SKILL.md');
      await skillMd.writeAsString(skill.toMarkdown());
    } catch (e) {
      log.e('SkillRegistry', '持久化技能失败: $e');
    }
  }

  /// 持久化 cookbook 文件
  Future<void> persistCookbook(String skillId, String fileName, String content) async {
    try {
      final dir = await _skillDir();
      final cookbookDir = Directory('${dir.path}/$skillId/cookbook');
      if (!cookbookDir.existsSync()) cookbookDir.createSync(recursive: true);
      final file = File('${cookbookDir.path}/$fileName');
      await file.writeAsString(content);
    } catch (e) {
      log.e('SkillRegistry', '持久化cookbook失败: $e');
    }
  }

  /// 删除一个自定义 Skill（磁盘目录 + 内存）
  Future<void> deleteSkill(String skillId) async {
    _skills.remove(skillId);
    try {
      final dir = await _skillDir();
      final skillDir = Directory('${dir.path}/$skillId');
      if (skillDir.existsSync()) skillDir.deleteSync(recursive: true);
    } catch (e) {
      log.e('SkillRegistry', '删除技能 $skillId 失败: $e');
    }
  }
}
