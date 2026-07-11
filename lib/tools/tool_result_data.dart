/// 工具结构化结果基类。
///
/// 借鉴 Operit `ToolResultData`：工具可返回结构化数据（而非仅字符串），
/// UI / 下游可按类型消费。[toDisplayString] 提供人类可读文本（即旧版
/// [ToolResult.content]），[toJson] 提供机器可读结构。
///
/// 本 app 采用轻量实现：仅抽取最常用的几种结构类型，工具仍主要返回字符串，
/// 需要结构化展示时（如列表、键值对）可附带 [ToolResult.data]。
abstract class ToolResultData {
  const ToolResultData();

  String toDisplayString();
  Map<String, dynamic> toJson();

  @override
  String toString() => toDisplayString();
}

/// 纯文本结果。
class TextResultData extends ToolResultData {
  final String value;
  const TextResultData(this.value);
  @override
  String toDisplayString() => value;
  @override
  Map<String, dynamic> toJson() => {'type': 'text', 'value': value};
}

/// 错误结果。
class ErrorResultData extends ToolResultData {
  final String message;
  const ErrorResultData(this.message);
  @override
  String toDisplayString() => message;
  @override
  Map<String, dynamic> toJson() => {'type': 'error', 'message': message};
}

/// 列表结果（如笔记列表、搜索结果）。
class ListResultData extends ToolResultData {
  final List<Map<String, dynamic>> items;
  final String? emptyHint;
  final String? itemTitleKey;
  final String? itemValueKey;

  const ListResultData(
    this.items, {
    this.emptyHint,
    this.itemTitleKey,
    this.itemValueKey,
  });

  @override
  String toDisplayString() {
    if (items.isEmpty) return emptyHint ?? '（无结果）';
    return items.map((m) {
      if (itemTitleKey != null && itemValueKey != null) {
        return '- ${m[itemTitleKey]}：${m[itemValueKey]}';
      }
      return '- ${m.entries.map((e) => '${e.key}: ${e.value}').join(', ')}';
    }).join('\n');
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'list',
        'count': items.length,
        'items': items,
      };
}

/// 键值对结果（如配置、元信息）。
class KeyValueResultData extends ToolResultData {
  final Map<String, String> pairs;
  const KeyValueResultData(this.pairs);
  @override
  String toDisplayString() =>
      pairs.entries.map((e) => '${e.key}：${e.value}').join('\n');
  @override
  Map<String, dynamic> toJson() => {'type': 'keyvalue', 'pairs': pairs};
}
