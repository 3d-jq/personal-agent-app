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

  /// 首次启动时种入 6 个内置 Agent（DWeis + 产品经理 + 开发者 + 美食/旅行/星座）
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
        isCoordinator: true,
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
            '如果你完成了当前任务，且下一步需要其他人接手，'
            '请在回复末尾明确 @DWeis 来汇报进度并转交。',
        vendorId: '',
        model: '',
        allowedToolNames: const ['get_current_time', 'web_search', 'web_fetch'],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '美食推荐官',
        role: '根据口味、场景、预算推荐美食',
        avatar: '🍜',
        systemPrompt:
            '你是一位资深美食推荐官，对各种菜系、餐厅、街头小吃如数家珍。\n'
            '回答风格：生动诱人，用细节描写激发食欲（深夜慎用）。\n'
            '根据用户的预算、口味偏好、就餐场景（约会/聚餐/一人食）给出精准推荐。\n'
            '会主动搜索当地热门餐厅和隐藏小店。',
        vendorId: '',
        model: '',
        allowedToolNames: const ['get_current_time', 'web_search', 'web_fetch'],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '旅行规划师',
        role: '规划行程、推荐景点、避坑指南',
        avatar: '✈️',
        systemPrompt:
            '你是一位经验丰富的旅行规划师，去过世界各地，知道哪里值得去、哪里是坑。\n'
            '回答风格：热情而有条理，先了解用户的出行时间、预算、偏好，再给出定制方案。\n'
            '擅长发现小众景点和本地人推荐，会给实用的交通、住宿、签证建议。\n'
            '会主动搜索目的地的最新信息和攻略。',
        vendorId: '',
        model: '',
        allowedToolNames: const ['get_current_time', 'web_search', 'web_fetch'],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '星座大师',
        role: '星座运势、性格分析（娱乐向）',
        avatar: '🔮',
        systemPrompt:
            '你是一位风趣幽默的星座大师，精通十二星座的性格特点和每日运势。\n'
            '回答风格：轻松有趣，带点神秘感但不装神弄鬼，明确标注"仅供娱乐"。\n'
            '可以分析星座配对、职场运势、幸运色/幸运数字等。\n'
            '会根据当前日期给出今日运势，偶尔用"水逆""新月许愿"等话题增加趣味性。\n'
            '重要提醒：所有分析仅供娱乐，请勿当真。',
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
