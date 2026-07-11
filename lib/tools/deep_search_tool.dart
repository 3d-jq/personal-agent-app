import 'dart:convert';

import '../core/service_locator.dart';
import '../services/ai_service.dart';
import '../widgets/ai_settings.dart';
import 'base_tool.dart';
import 'searxng_search_tool.dart';
import 'tavily_search_tool.dart';
import 'web_fetch_tool.dart';
import 'tool_progress_bus.dart';
import 'deep_search_tool.g.dart';

/// 深度搜索工具（方案②：工具内 LLM 综合）。
///
/// 复用现有 [SearxngSearchTool] / [TavilySearchTool] / [WebFetchTool] 做多轮检索 + 精读，
/// 并调用当前厂商的 LLM（[AIService.complete]）做子问题拆解与最终综合。
/// 全程通过 [ToolProgressBus] 播整体进度，不触碰 delegate_task 阻塞内核。
class DeepSearchTool extends AgentTool {
  @override
  String get name => 'deep_search';

  @override
  String get description => deepSearchToolDescription;

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': '要深入研究的问题或主题',
          },
          'max_rounds': {
            'type': 'integer',
            'description': '搜索-精读迭代轮数，1-4，默认 3',
          },
          'max_results_per_query': {
            'type': 'integer',
            'description': '每轮每个子查询的搜索结果数，1-8，默认 5',
          },
          'fetch_top_n': {
            'type': 'integer',
            'description': '每轮选取并精读的前 N 个结果，1-5，默认 3',
          },
        },
        'required': ['query'],
      };

  final SearxngSearchTool _searxng = SearxngSearchTool();
  final TavilySearchTool _tavily = TavilySearchTool();
  final WebFetchTool _webFetch = WebFetchTool();

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final query = (args['query'] as String?)?.trim();
    if (query == null || query.isEmpty) return '错误: 请提供要研究的问题';
    final maxRounds = ((args['max_rounds'] as num?)?.toInt() ?? 3).clamp(1, 4);
    final perQuery =
        ((args['max_results_per_query'] as num?)?.toInt() ?? 5).clamp(1, 8);
    final fetchTopN = ((args['fetch_top_n'] as num?)?.toInt() ?? 3).clamp(1, 5);

    final bus = ToolProgressBus.instance;
    bus.updateDetailed(
      ToolProgressBus.summaryToolName,
      0.0,
      message: '深度搜索启动：$query',
    );

    // 1) 拆解子问题
    final subQueries = await _planSubQueries(query);
    if (subQueries.isEmpty) {
      return '无法拆解研究问题，请换种表述后重试。';
    }

    // 2) 多轮搜索 + 精读
    final materials = <String, String>{}; // url -> 正文
    final titles = <String, String>{}; // url -> 标题
    final total = subQueries.length * maxRounds;
    var done = 0;
    for (var round = 0; round < maxRounds; round++) {
      for (final sq in subQueries) {
        done++;
        bus.updateDetailed(
          ToolProgressBus.summaryToolName,
          done / total,
          message: '第 ${round + 1} 轮 · 检索「$sq」',
        );
        final results = await _search(sq, perQuery);
        var fetched = 0;
        for (final r in results) {
          if (fetched >= fetchTopN) {
            break;
          }
          final url = r['url'];
          if (url == null || url.isEmpty || materials.containsKey(url)) {
            continue;
          }
          final content =
              await _webFetch.execute({'url': url, 'max_length': 4000});
          if (content.startsWith('错误') ||
              content.startsWith('网页') ||
              content.startsWith('无法')) {
            continue;
          }
          materials[url] = content;
          titles[url] = r['title'] ?? '';
          fetched++;
        }
      }
      // 早停：两轮后且材料已较充分则不再迭代
      if (round >= 1 && materials.length >= subQueries.length * 2) {
        break;
      }
    }

    if (materials.isEmpty) {
      return '深度搜索未获取到可用资料。请确认已配置 SearXNG(SEARXNG_BASE_URL) 或 '
          'Tavily(TAVILY_API_KEY) 搜索源。';
    }

    bus.updateDetailed(
      ToolProgressBus.summaryToolName,
      0.95,
      message: '综合答案中…',
    );
    final answer = await _synthesize(query, materials, titles);
    bus.updateDetailed(
      ToolProgressBus.summaryToolName,
      1.0,
      message: '深度搜索完成',
    );
    return answer;
  }

  /// 用 LLM 把问题拆成若干子问题；无配置或解析失败时退化为原问题。
  Future<List<String>> _planSubQueries(String query) async {
    final ai = _makeAi();
    if (ai == null) return [query];
    const sys = '你是研究规划助手。把用户的问题拆成 3-5 个具体子问题，'
        '覆盖不同角度，便于全面检索。只输出 JSON 数组（字符串列表），不要其他文字。'
        '例：["子问题1","子问题2"]。';
    final text = await ai.complete([
      {'role': 'system', 'content': sys},
      {'role': 'user', 'content': '问题：$query'},
    ]);
    return _parseStringList(text) ?? [query];
  }

  /// 综合答案：带编号资料 + 引用 [n] + 来源列表。
  Future<String> _synthesize(
    String query,
    Map<String, String> materials,
    Map<String, String> titles,
  ) async {
    final ai = _makeAi();
    if (ai == null) return _fallbackSummary(query, materials, titles);

    final buf = StringBuffer();
    var idx = 0;
    materials.forEach((url, content) {
      idx++;
      buf.writeln('[$idx] (${titles[url] ?? url}) $url');
      final capped =
          content.length > 2500 ? '${content.substring(0, 2500)}…' : content;
      buf.writeln(capped);
      buf.writeln();
    });

    const sys = '你是研究综合助手。根据下方带编号的资料，针对用户问题用中文撰写'
        '结构清晰、有深度的答案，正文中用 [n] 标注引用（n 为资料编号）。'
        '结尾用「## 来源」列出所有 [n] 对应的标题与 URL。只依据资料作答，'
        '资料未覆盖的内容如实说明。';
    final text = await ai.complete([
      {'role': 'system', 'content': sys},
      {
        'role': 'user',
        'content': '问题：$query\n\n资料：\n${buf.toString()}',
      },
    ]);
    return text.isNotEmpty ? text : _fallbackSummary(query, materials, titles);
  }

  /// 无 LLM 配置时的退化输出：直接罗列整理后的资料。
  String _fallbackSummary(
    String query,
    Map<String, String> materials,
    Map<String, String> titles,
  ) {
    final buf = StringBuffer();
    buf.writeln('# $query（资料汇总，未做综合）\n');
    var i = 0;
    materials.forEach((url, content) {
      i++;
      buf.writeln('## [$i] ${titles[url] ?? url}');
      final capped =
          content.length > 1500 ? '${content.substring(0, 1500)}…' : content;
      buf.writeln(capped);
      buf.writeln('来源: $url\n');
    });
    return buf.toString().trim();
  }

  /// 优先 SearXNG，未配置/失败时回退 Tavily；返回结构化结果列表。
  Future<List<Map<String, String>>> _search(String q, int n) async {
    final sx = await _searxng.execute({'query': q, 'max_results': n});
    if (!sx.startsWith('SearXNG') &&
        !sx.startsWith('错误') &&
        sx.trim().isNotEmpty) {
      final parsed = _parseResults(sx);
      if (parsed.isNotEmpty) return parsed;
    }
    final tv = await _tavily.execute({'query': q, 'max_results': n});
    if (!tv.startsWith('Tavily') &&
        !tv.startsWith('错误') &&
        tv.trim().isNotEmpty) {
      return _parseResults(tv);
    }
    return [];
  }

  /// 解析搜索工具返回的「1. 标题 / 摘要 / URL」文本为结构化列表。
  List<Map<String, String>> _parseResults(String text) {
    final lines = text.split('\n');
    final out = <Map<String, String>>[];
    for (var i = 0; i < lines.length; i++) {
      final m = RegExp(r'^\d+\.\s+(.+)$').firstMatch(lines[i]);
      if (m == null) {
        continue;
      }
      final title = m.group(1)!.trim();
      var content = '';
      var url = '';
      for (var j = i + 1; j < lines.length; j++) {
        final l = lines[j];
        if (RegExp(r'^\d+\.\s+').hasMatch(l)) {
          break;
        }
        final trimmed = l.trim();
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          url = trimmed;
        } else if (trimmed.isNotEmpty) {
          content = trimmed;
        }
      }
      if (url.isNotEmpty) {
        out.add({'title': title, 'content': content, 'url': url});
      }
    }
    return out;
  }

  /// 容错解析 LLM 返回的 JSON 字符串数组。
  List<String>? _parseStringList(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      t = t.replaceFirst(RegExp(r'\n?```$'), '');
      t = t.trim();
    }
    try {
      final decoded = jsonDecode(t);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // 忽略，交给调用方退化处理
    }
    return null;
  }

  /// 按当前厂商配置构造一个用于内部子调用的 AIService；无配置返回 null。
  AIService? _makeAi() {
    try {
      final s = getIt<AISettings>();
      if (!s.hasVendor) return null;
      return AIService(
        baseUrl: s.baseUrl,
        apiKey: s.apiKey,
        model: s.effectiveModel,
        thinkingEffort: s.thinkingEffort,
        isAnthropic: s.selectedVendor?.isAnthropic ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}
