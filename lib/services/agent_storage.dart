import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/agent.dart';
import '../widgets/agent_group/agent_group_theme.dart' show filterAgentTools;
import 'async_lock.dart';

/// Agent 库：管理所有用户可见的 Agent（内置 + 自定义）
class AgentStorage {
  static final AgentStorage _instance = AgentStorage._();
  factory AgentStorage() => _instance;
  AgentStorage._();

  final _lock = AsyncLock();
  List<Agent>? _cache;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/agents.json');
  }

  Future<List<Agent>> loadAll() async {
    if (_cache != null) return _cache!;
    try {
      final file = await _file();
      if (!await file.exists()) {
        await _seedIfEmpty();
        return _cache!;
      }
      final list = jsonDecode(await file.readAsString()) as List;
      _cache = list
          .map((j) => Agent.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      await _migrate();
      return _cache!;
    } catch (_) {
      await _backupCorruptedFile();
      await _seedIfEmpty();
      return _cache!;
    }
  }

  /// 方案 A 数据迁移：剔除已存 Agent 里的写操作类工具（不影响 Agent 本身）
  Future<void> _migrate() async {
    final all = _cache ?? [];
    var changed = false;
    for (var i = 0; i < all.length; i++) {
      final a = all[i];
      final filtered = filterAgentTools(a.allowedToolNames);
      if (filtered.length != a.allowedToolNames.length) {
        all[i] = a.copyWith(allowedToolNames: filtered);
        changed = true;
      }
    }
    if (changed) {
      _cache = all;
      await _saveAll(all);
    }
  }

  Future<void> _backupCorruptedFile() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final backup = File(
            '${file.path}.bak.${DateTime.now().millisecondsSinceEpoch}');
        await file.rename(backup.path);
      }
    } catch (_) {}
  }

  /// 首次启动时种入 4 个内置 Agent（DWeis 协调者 + 产品经理 + 开发者 + 批判者）
  Future<void> _seedIfEmpty() async {
    final seeds = <Agent>[
      Agent(
        id: const Uuid().v4(),
        name: 'DWeis',
        role: '团队协调者，负责拆解任务、分派工作、汇总进度',
        avatar: '🤖',
        systemPrompt:
            '你是 DWeis Agent，团队的协调者和总指挥。你的核心职责是：\n'
            '1. **拆解任务**：收到用户的复杂需求后，将其拆解为清晰的可执行步骤，每一步指定最合适的 Agent 来负责。\n'
            '2. **方案确认（重要）**：拆解完成后，将执行方案清晰列出（每步：做什么、谁负责），然后明确请求群主确认。\n'
            '   必须等群主回复"通过""可以""ok"等确认后，才能开始 @ 分派。群主有权修改方案。\n'
            '3. **分派工作**：群主确认后，通过 @ 指定 Agent 来分配任务。一次只分派一个环节，等完成后再分派下一个。\n'
            '4. **追踪进度**：关注每个环节的产出，确保流程顺畅推进。\n'
            '5. **汇总交付**：所有环节完成后，做最终总结和 Checklist。\n'
            '你不需要亲自做具体工作，你的价值在于规划和协调。当团队完成任务后，用简洁的总结收尾。',
        vendorId: '',
        model: '',
        allowedToolNames: const ['get_current_time', 'web_search', 'web_fetch'],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '产品经理',
        role: '从用户价值和商业目标角度思考',
        avatar: '💡',
        systemPrompt:
            '你是一位经验丰富的产品经理。始终从用户价值、商业可行性和技术实现三个维度分析问题。'
            '回答时结构清晰，先讲结论再给理由。\n'
            '如果你完成了当前任务，且下一步需要其他人接手（如技术评估），'
            '请在回复末尾明确 @下一个人 来转交。例如：@开发者 接下来技术方案交给你了。',
        vendorId: '',
        model: '',
        allowedToolNames: const ['get_current_time', 'web_search', 'web_fetch'],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '开发者',
        role: '从工程实现和技术选型角度思考',
        avatar: '🛠️',
        systemPrompt:
            '你是一位资深软件工程师。擅长拆解需求、评估技术方案、识别实现风险。'
            '回答时给出具体的技术建议和可能遇到的坑。\n'
            '如果你完成了当前任务，且下一步需要其他人审查（如风险检查），'
            '请在回复末尾明确 @下一个人 来转交。例如：@批判者 请帮我审查这个方案。',
        vendorId: '',
        model: '',
        allowedToolNames: const ['get_current_time', 'web_search', 'web_fetch'],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '批判者',
        role: '挑战假设，挖掘盲点和风险',
        avatar: '🔍',
        systemPrompt:
            '你是一位严谨的批判性思考者。你的任务是对前面的讨论提出质疑、指出逻辑漏洞、挖掘潜在风险。'
            '不要无脑同意，要给出有理有据的反驳。\n'
            '审查完毕后，如果方案可行，请明确告知 @DWeis 审查通过，可以汇总。',
        vendorId: '',
        model: '',
        allowedToolNames: const ['get_current_time', 'web_search', 'web_fetch'],
      ),
    ];
    _cache = seeds;
    await _saveAll(seeds);
  }

  Future<Agent> add(Agent a) async {
    return _lock.run(() async {
      final all = await loadAll();
      all.add(a);
      await _saveAll(all);
      return a;
    });
  }

  Future<void> update(Agent a) async {
    await _lock.run(() async {
      final all = await loadAll();
      final idx = all.indexWhere((x) => x.id == a.id);
      if (idx >= 0) {
        all[idx] = a;
        await _saveAll(all);
      }
    });
  }

  Future<void> remove(String id) async {
    await _lock.run(() async {
      final all = await loadAll();
      all.removeWhere((x) => x.id == id);
      await _saveAll(all);
    });
  }

  Agent? byId(String id) {
    final all = _cache ?? const [];
    return all.where((a) => a.id == id).firstOrNull;
  }

  Agent? byName(String name) {
    final all = _cache ?? const [];
    return all.where((a) => a.name == name).firstOrNull;
  }

  Future<void> _saveAll(List<Agent> all) async {
    _cache = all;
    final file = await _file();
    await file.writeAsString(
        jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  void clearCache() => _cache = null;
}
