// 集中放 Agent 群相关的工具/解析函数，避免 widgets 互相 import
import '../../models/agent.dart';

/// 从一段消息文本中解析精确匹配的 @Agent 名字列表
/// 规则：扫描 @xxx，xxx 必须是 group 里的某个 Agent.name（精确匹配）
List<String> parseMentions(String text, List<Agent> groupAgents) {
  final reg = RegExp(r'@([\p{L}\p{N}_\-]+)', unicode: true);
  final names = groupAgents.map((a) => a.name).toSet();
  final result = <String>[];
  for (final m in reg.allMatches(text)) {
    final name = m.group(1) ?? '';
    if (names.contains(name) && !result.contains(name)) {
      result.add(name);
    }
  }
  return result;
}

/// 工具列表（建群/编辑 Agent 时勾选用）—— 与 chat_helpers 里的中文 label 对齐
class ToolOption {
  final String name;
  final String label;
  const ToolOption(this.name, this.label);
}

const List<ToolOption> kAgentToolOptions = [
  ToolOption('weather', '查询天气'),
  ToolOption('searxng_search', 'SearXNG搜索'),
  ToolOption('tavily_search', 'Tavily搜索'),
  ToolOption('web_fetch', '获取网页'),
  ToolOption('tool_search', '发现工具'),
  ToolOption('defer_execute_tool', '调用延迟工具'),
  ToolOption('generate_image', '生成图片'),
  ToolOption('generate_video', '生成视频'),
];

/// 方案 A 严格隔离：会修改用户状态的工具黑名单
/// Agent 编辑页不让勾选这些；旧数据迁移时也用这个过滤
const Set<String> kAgentWriteStateTools = {
  'save_note',
  'save_memory',
  'reminder',
  'file_manager',
  'clipboard',
  'calendar',
};

/// 已下线的工具：旧 Agent 数据迁移时自动剔除
const Set<String> kDeprecatedTools = {
  'get_current_time',
  'web_search',
};

/// 把"已选工具名"映射成中文 label，便于在卡片上展示
String toolOptionsLabel(List<String> names) {
  if (names.isEmpty) return '无可用工具';
  return names.map((n) {
    final opt = kAgentToolOptions.where((o) => o.name == n).firstOrNull;
    return opt?.label ?? n;
  }).join(' · ');
}

/// 从工具列表中剔除写操作类及已下线工具（数据迁移/历史 Agent 清理用）
List<String> filterAgentTools(List<String> tools) {
  return tools.where((n) => !kAgentWriteStateTools.contains(n) && !kDeprecatedTools.contains(n)).toList();
}
