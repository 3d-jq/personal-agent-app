import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'tools.dart';
import '../core/service_locator.dart';
import '../services/crypto_util.dart';
import '../services/mcp_manager.dart';

/// 安全读取环境变量，测试环境未加载 dotenv 时返回空字符串。
String _safeEnv(String key) {
  try {
    return dotenv.env[key] ?? '';
  } catch (_) {
    return '';
  }
}

/// 能力插件接口。
///
/// 借鉴 Operit `OperitPlugin(id + register)`：
/// - [id] 唯一标识；
/// - [init] 一次性全局副作用（加载 Skill、连接 MCP）；
/// - [provideTools] 向某个会话的 [ToolRegistry] 注入本插件提供的工具。
///
/// 重要：本 app 的 [ToolRegistry] 是「每会话实例」（每个对话独立），
/// 因此插件不持有全局工具列表，而是按会话「注入」。[provideTools] 必须幂等
/// （用 `registry.has(name)` 守卫），避免重复注册重置有状态工具。
abstract class AppPlugin {
  String get id;
  Future<void> init();
  void provideTools(ToolRegistry registry);
}

/// 内置核心工具插件（原 chat_helpers.registerAllTools）。
class CoreToolsPlugin extends AppPlugin {
  @override
  String get id => 'core-tools';

  @override
  Future<void> init() async {}

  @override
  void provideTools(ToolRegistry registry) {
    // 高频基础工具（用 has 守卫，幂等）
    // task_plan 拆分为 6 个独立工具，共享同一 TaskPlanStore 实例（计划状态会话内一致）
    final planStore = TaskPlanStore();
    if (!registry.has('plan_create')) registry.register(PlanCreateTool(planStore));
    if (!registry.has('plan_update')) registry.register(PlanUpdateTool(planStore));
    if (!registry.has('plan_advance')) registry.register(PlanAdvanceTool(planStore));
    if (!registry.has('plan_status')) registry.register(PlanStatusTool(planStore));
    if (!registry.has('plan_clear')) registry.register(PlanClearTool(planStore));
    if (!registry.has('plan_verify')) registry.register(PlanVerifyTool(planStore));
    if (!registry.has('reminder')) registry.register(ReminderTool());
    if (!registry.has('web_fetch')) registry.register(WebFetchTool());
    if (!registry.has('weather')) {
      registry.register(
          WeatherTool(apiKey: CryptoUtil.decrypt(_safeEnv('GAODE_API_KEY'))));
    }
    if (!registry.has('location')) registry.register(LocationTool());
    if (!registry.has('searxng_search')) registry.register(SearxngSearchTool());
    if (!registry.has('tavily_search')) registry.register(TavilySearchTool());
    if (!registry.has('deep_search')) registry.register(DeepSearchTool());
    final agnesKey = CryptoUtil.decrypt(_safeEnv('AGNES_API_KEY'));
    if (!registry.has('generate_image')) {
      registry.register(AgnesImageTool(apiKey: agnesKey));
    }
    if (!registry.has('generate_video')) {
      registry.register(AgnesVideoTool(apiKey: agnesKey));
    }
    if (!registry.has('save_note')) registry.register(SaveNoteTool());
    // manage_notes 拆分为 4 个独立工具
    if (!registry.has('notes_list')) registry.register(NotesListTool());
    if (!registry.has('notes_read')) registry.register(NotesReadTool());
    if (!registry.has('notes_update')) registry.register(NotesUpdateTool());
    if (!registry.has('notes_delete')) registry.register(NotesDeleteTool());
    if (!registry.has('create_rich_note')) registry.register(CreateRichNoteTool());
    if (!registry.has('ai_daily')) registry.register(AiDailyTool());
    // context_doc 拆分为 2 个独立工具
    if (!registry.has('context_doc_read')) registry.register(ContextDocReadTool());
    if (!registry.has('context_doc_update')) registry.register(ContextDocUpdateTool());
    // virtual_fs 拆分为 6 个独立工具
    if (!registry.has('fs_ls')) registry.register(FsLsTool());
    if (!registry.has('fs_read')) registry.register(FsReadTool());
    if (!registry.has('fs_write')) registry.register(FsWriteTool());
    if (!registry.has('fs_mkdir')) registry.register(FsMkdirTool());
    if (!registry.has('fs_rm')) registry.register(FsRmTool());
    if (!registry.has('fs_walk')) registry.register(FsWalkTool());
    // skill_manage 拆分为 5 个独立工具
    if (!registry.has('skill_list')) registry.register(SkillListTool());
    if (!registry.has('skill_read')) registry.register(SkillReadTool());
    if (!registry.has('skill_read_cookbook')) registry.register(SkillReadCookbookTool());
    if (!registry.has('skill_create')) registry.register(SkillCreateTool());
    if (!registry.has('skill_match')) registry.register(SkillMatchTool());

    // 工具发现层（需引用 registry，构造一次即可）
    if (!registry.has('tool_search')) {
      registry.register(ToolSearchTool(registry: registry));
    }
    if (!registry.has('defer_execute_tool')) {
      registry.register(DeferExecuteTool(registry: registry));
    }

    // 低频/场景化工具（按需发现）
    if (!registry.has('calendar_query')) registry.registerDiscoverable(CalendarQueryTool());
    if (!registry.has('calendar_add')) registry.registerDiscoverable(CalendarAddTool());
    if (!registry.has('calendar_delete')) registry.registerDiscoverable(CalendarDeleteTool());
  }
}

/// 技能插件：确保 [SkillRegistry] 已加载内置/自定义技能。
///
/// 技能本身通过 skill_* 工具暴露给模型，无需在此注册工具。
class SkillPlugin extends AppPlugin {
  @override
  String get id => 'skill';

  @override
  Future<void> init() async {
    final sr = getIt<SkillRegistry>();
    await sr.loadFromDisk();
    sr.registerBuiltInSkills();
  }

  @override
  void provideTools(ToolRegistry registry) {}
}

/// MCP 插件：连接已启用的 MCP 服务器，并把它提供的工具注入会话。
class McpPlugin extends AppPlugin {
  @override
  String get id => 'mcp';

  @override
  Future<void> init() async {
    await getIt<McpManager>().autoConnect();
  }

  @override
  void provideTools(ToolRegistry registry) {
    try {
      final mcpManager = getIt<McpManager>();
      // 先移除旧 MCP 工具，避免断开的服务器工具残留
      final oldMcpNames = registry.all
          .where((t) => t.name.startsWith('mcp_'))
          .map((t) => t.name)
          .toList();
      for (final name in oldMcpNames) {
        registry.unregister(name);
      }
      // 注入当前已连接服务器的工具
      for (final entry in mcpManager.clients.entries) {
        final serverId = entry.key;
        final client = entry.value;
        for (final tool in client.tools) {
          registry.register(McpToolAdapter(
            serverId: serverId,
            name: tool.name,
            description: tool.description,
            inputSchema: tool.inputSchema,
          ));
        }
      }
    } catch (_) {
      // McpManager 未初始化时忽略
    }
  }
}

/// 插件注册表。
///
/// 借鉴 Operit `PluginRegistry`：统一管理内置能力插件的生命周期
/// （[register] → [registerBuiltins] → [init]），并对外提供
/// [registerCapabilities] 把全部插件能力注入某个会话的 [ToolRegistry]。
///
/// 三个内置插件：
/// - [CoreToolsPlugin]：所有内置 Agent 工具；
/// - [SkillPlugin]：技能加载与注册；
/// - [McpPlugin]：MCP 服务器连接与工具同步。
class PluginRegistry {
  PluginRegistry._();
  static final PluginRegistry instance = PluginRegistry._();

  final List<AppPlugin> _plugins = [];
  final Set<String> _installed = {};
  bool _initialized = false;

  /// 注册一个插件（按 id 去重）。
  void register(AppPlugin plugin) {
    _plugins.removeWhere((p) => p.id == plugin.id);
    _plugins.add(plugin);
  }

  /// 注册全部内置插件（应在 [init] 之前调用一次）。
  void registerBuiltins() {
    register(CoreToolsPlugin());
    register(SkillPlugin());
    register(McpPlugin());
    register(BrowserToolsPlugin());
  }

  /// 执行一次性初始化（加载技能、连接 MCP）。幂等。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    for (final p in _plugins) {
      if (_installed.add(p.id)) {
        await p.init();
      }
    }
  }

  /// 向会话 [ToolRegistry] 注入全部插件能力。
  ///
  /// 幂等：核心工具用 [CoreToolsPlugin] 的 has 守卫；MCP 每次重新同步
  /// （支持运行时新连接的服务器）。可安全在「构造时」与「每次发消息前」重复调用。
  void registerCapabilities(ToolRegistry registry) {
    for (final p in _plugins) {
      p.provideTools(registry);
    }
  }

  /// 复位（主要用于测试）。清空已安装标记与插件列表。
  void reset() {
    _initialized = false;
    _installed.clear();
    _plugins.clear();
  }
}
