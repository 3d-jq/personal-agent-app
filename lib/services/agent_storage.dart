import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/agent.dart';
import '../widgets/agent_group/agent_group_theme.dart' show filterAgentTools;
import 'async_lock.dart';

/// Agent 库：管理所有用户可见的 Agent（内置 + 自定义）
class AgentStorage {
  AgentStorage();

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

  /// 首次启动时种入 7 个内置 Agent（Prompt 从 assets/agents/*.md 加载）
  Future<void> _seedIfEmpty() async {
    final seeds = <Agent>[
      Agent(
        id: const Uuid().v4(),
        name: 'DWeis',
        role: '团队协调者，负责拆解任务、分派工作、汇总进度',
        avatar: '🤖',
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
        avatar: '💡',
        systemPrompt: await _loadPrompt('pm.md'),
        vendorId: '',
        model: '',
        allowedToolNames: const ['searxng_search', 'tavily_search', 'web_fetch', 'tool_search', 'defer_execute_tool'],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '开发者',
        role: '从工程实现和技术选型角度思考',
        avatar: '🛠️',
        systemPrompt: await _loadPrompt('dev.md'),
        vendorId: '',
        model: '',
        allowedToolNames: const ['searxng_search', 'tavily_search', 'web_fetch', 'tool_search', 'defer_execute_tool'],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '美食推荐官',
        role: '根据口味、场景、预算推荐美食',
        avatar: '🍜',
        systemPrompt: await _loadPrompt('food.md'),
        vendorId: '',
        model: '',
        allowedToolNames: const ['searxng_search', 'tavily_search', 'web_fetch', 'tool_search', 'defer_execute_tool'],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '旅行规划师',
        role: '规划行程、推荐景点、避坑指南',
        avatar: '✈️',
        systemPrompt: await _loadPrompt('travel.md'),
        vendorId: '',
        model: '',
        allowedToolNames: const ['searxng_search', 'tavily_search', 'web_fetch', 'tool_search', 'defer_execute_tool'],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '星座大师',
        role: '星座运势、性格分析（娱乐向）',
        avatar: '🔮',
        systemPrompt: await _loadPrompt('zodiac.md'),
        vendorId: '',
        model: '',
        allowedToolNames: const ['searxng_search', 'tavily_search', 'web_fetch', 'tool_search', 'defer_execute_tool'],
      ),
      Agent(
        id: const Uuid().v4(),
        name: '高考志愿规划师',
        role: '高考志愿填报指导，张雪峰式现实主义选校顾问',
        avatar: '🎓',
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
    ];
    _cache = seeds;
    await _saveAll(seeds);
  }

  /// 从 assets/agents/ 目录加载 Agent 的 system prompt
  static Future<String> _loadPrompt(String filename) async {
    try {
      return await rootBundle.loadString('assets/agents/$filename');
    } catch (_) {
      return '';
    }
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
