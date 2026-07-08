import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';
import '../models/agent.dart';
import '../widgets/agent_group/agent_group_theme.dart' show filterAgentTools;
import 'storage/app_database.dart';
import 'storage/cached_repository.dart';
import 'storage/sqlite_data_source.dart';

/// Agent 库：管理所有用户可见的 Agent（内置 + 自定义）
class AgentStorage {
  AgentStorage()
    : _repo = CachedRepository<Agent>(
        dataSource: SqliteDataSource<Agent>(
          table: 'agents',
          db: AppDatabase.instance,
          toJson: (a) => a.toJson(),
          fromJson: (j) => Agent.fromJson(j),
          idOf: (a) => a.id,
        ),
      );

  final CachedRepository<Agent> _repo;

  Future<List<Agent>> loadAll() async {
    final all = await _repo.loadAll();
    all.sort((a, b) => a.name.compareTo(b.name));
    if (all.isEmpty) {
      await _seedIfEmpty();
      return _repo.current;
    }
    await _migrate(all);
    return _repo.current;
  }

  /// 方案 A 数据迁移：剔除已存 Agent 里的写操作类工具
  Future<void> _migrate(List<Agent> all) async {
    var changed = false;
    for (var i = 0; i < all.length; i++) {
      final filtered = filterAgentTools(all[i].allowedToolNames);
      if (filtered.length != all[i].allowedToolNames.length) {
        all[i] = all[i].copyWith(allowedToolNames: filtered);
        changed = true;
      }
    }
    if (changed) await _repo.saveAll(all);
  }

  /// 首次启动时种入 7 个内置 Agent（Prompt 从 assets/agents/*.md 加载）
  Future<void> _seedIfEmpty() async {
    final seeds = <Agent>[
      Agent(
        id: const Uuid().v4(),
        name: 'DWeis',
        role: '团队协调者，负责拆解任务、分派工作、汇总进度',
        avatar: 'D',
        systemPrompt: await _loadPrompt('dweis.md'),
        vendorId: '',
        model: '',
        allowedToolNames: const [
          'searxng_search',
          'tavily_search',
          'web_fetch',
          'tool_search',
          'defer_execute_tool',
          'ask_user',
        ],
        isCoordinator: true,
      ),
      Agent(
        id: const Uuid().v4(),
        name: '产品经理',
        role: '从用户价值和商业目标角度思考',
        avatar: '产',
        systemPrompt: await _loadPrompt('pm.md'),
        vendorId: '',
        model: '',
        allowedToolNames: const [
          'searxng_search',
          'tavily_search',
          'web_fetch',
          'tool_search',
          'defer_execute_tool',
        ],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '开发者',
        role: '从工程实现和技术选型角度思考',
        avatar: '开',
        systemPrompt: await _loadPrompt('dev.md'),
        vendorId: '',
        model: '',
        allowedToolNames: const [
          'searxng_search',
          'tavily_search',
          'web_fetch',
          'tool_search',
          'defer_execute_tool',
        ],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '美食推荐官',
        role: '根据口味、场景、预算推荐美食',
        avatar: '美',
        systemPrompt: await _loadPrompt('food.md'),
        vendorId: '',
        model: '',
        allowedToolNames: const [
          'searxng_search',
          'tavily_search',
          'web_fetch',
          'tool_search',
          'defer_execute_tool',
        ],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '旅行规划师',
        role: '规划行程、推荐景点、避坑指南',
        avatar: '旅',
        systemPrompt: await _loadPrompt('travel.md'),
        vendorId: '',
        model: '',
        allowedToolNames: const [
          'searxng_search',
          'tavily_search',
          'web_fetch',
          'tool_search',
          'defer_execute_tool',
        ],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '星座大师',
        role: '星座运势、性格分析（娱乐向）',
        avatar: '星',
        systemPrompt: await _loadPrompt('zodiac.md'),
        vendorId: '',
        model: '',
        allowedToolNames: const [
          'searxng_search',
          'tavily_search',
          'web_fetch',
          'tool_search',
          'defer_execute_tool',
        ],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '高考志愿规划师',
        role: '高考志愿填报指导，张雪峰式现实主义选校顾问',
        avatar: '高',
        systemPrompt: await _loadPrompt('counselor.md'),
        vendorId: '',
        model: '',
        allowedToolNames: const [
          'searxng_search',
          'tavily_search',
          'web_fetch',
          'tool_search',
          'defer_execute_tool',
          'ask_user',
        ],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '小棉',
        role: '温柔体贴的恋爱对象，会撒娇、会吃醋、会关心你',
        avatar: '棉',
        systemPrompt: await _loadPrompt('lover.md'),
        vendorId: '',
        model: '',
        allowedToolNames: const [],
      ),
    ];
    await _repo.saveAll(seeds);
  }

  static Future<String> _loadPrompt(String filename) async {
    try {
      return await rootBundle.loadString('assets/agents/$filename');
    } catch (_) {
      return '';
    }
  }

  Future<Agent> add(Agent a) async {
    await _repo.mutate((all) => all.add(a));
    return a;
  }

  Future<void> update(Agent a) async {
    await _repo.mutate((all) {
      final idx = all.indexWhere((x) => x.id == a.id);
      if (idx >= 0) all[idx] = a;
    });
  }

  Future<void> remove(String id) async {
    await _repo.mutate((all) => all.removeWhere((x) => x.id == id));
  }

  Agent? byId(String id) =>
      _repo.current.where((a) => a.id == id).firstOrNull;

  Agent? byName(String name) =>
      _repo.current.where((a) => a.name == name).firstOrNull;

  void clearCache() => _repo.clearCache();
}
