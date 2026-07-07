import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import '../services/crypto_util.dart';
import '../services/log_service.dart';
import 'vendor_config.dart';

/// AI 设置管理器
class AISettings {
  AISettings();

  static List<(String, String, String)> _builtIn = [];
  List<VendorConfig> vendors = [];
  String? selectedVendorId;
  bool _loaded = false;

  /// 思考强度: low / medium / high，默认 medium
  String thinkingEffort = 'medium';

  /// 上下文窗口大小（token 数），默认 256K
  int contextWindowSize = 256000;

  VendorConfig? get selectedVendor =>
      vendors.where((v) => v.id == selectedVendorId).firstOrNull;
  String get apiKey => selectedVendor?.apiKey ?? '';
  String get baseUrl => selectedVendor?.baseUrl ?? '';
  String get effectiveModel => selectedVendor?.model ?? '';
  bool get hasVendor =>
      selectedVendor != null && selectedVendor!.apiKey.isNotEmpty;

  void _ensureBuiltIn() {
    final agnesKey = CryptoUtil.decrypt(dotenv.env['AGNES_API_KEY'] ?? '');
    _builtIn = [
      ('Agnes-2.0-Flash', agnesKey, 'https://apihub.agnes-ai.com/v1'),
    ];
    for (final b in _builtIn) {
      if (!vendors.any((v) => v.name == b.$1)) {
        vendors.add(
          VendorConfig(
            id: b.$1,
            name: b.$1,
            apiKey: b.$2,
            baseUrl: b.$3,
            isBuiltIn: true,
          ),
        );
      }
    }
  }

  void selectVendor(String id) {
    selectedVendorId = id;
    save();
    final v = vendors.where((x) => x.id == id).firstOrNull;
    if (v != null && v.model.isEmpty) {
      final defaultModel = id == 'Agnes-2.0-Flash' ? 'agnes-2.0-flash' : 'deepseek-chat';
      final index = vendors.indexWhere((x) => x.id == id);
      if (index >= 0) {
        vendors[index] = v.copyWith(model: defaultModel);
        save();
      }
    }
  }

  void setVendorModel(String vid, String m) {
    final v = vendors.where((x) => x.id == vid).firstOrNull;
    if (v != null) {
      final index = vendors.indexWhere((x) => x.id == vid);
      if (index >= 0) {
        vendors[index] = v.copyWith(model: m);
        save();
      }
    }
  }

  void addVendor(VendorConfig v) {
    vendors.add(v);
    selectedVendorId = v.id;
    save();
  }

  void updateVendor(VendorConfig v) {
    final i = vendors.indexWhere((x) => x.id == v.id);
    if (i >= 0) vendors[i] = v;
    save();
  }

  void removeVendor(String id) {
    vendors.removeWhere((x) => x.id == id);
    if (selectedVendorId == id)
      selectedVendorId = vendors.isNotEmpty ? vendors.first.id : null;
    save();
  }

  Future<File> _file() async {
    final d = await getApplicationDocumentsDirectory();
    return File('${d.path}/ai_settings.json');
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await _file();
      if (await f.exists()) {
        final d = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        selectedVendorId = d['vendor'] as String?;
        vendors =
            (d['vendors'] as List?)
                ?.map((x) => VendorConfig.fromJson(x as Map<String, dynamic>))
                .toList() ??
            [];
        thinkingEffort = d['thinkingEffort'] as String? ?? 'medium';
        contextWindowSize = d['contextWindowSize'] as int? ?? 256000;
      }
    } catch (e) {
      log.w('AISettings', '加载AI设置失败: $e');
    }
    _ensureBuiltIn();
    if (selectedVendorId == null && vendors.isNotEmpty) {
      selectVendor(vendors.first.id);
    }
    _loaded = true;
  }

  Future<void> save() async {
    await _file().then(
      (f) => f.writeAsString(
        jsonEncode({
          'vendor': selectedVendorId,
          'vendors': vendors.map((v) => v.toJson()).toList(),
          'thinkingEffort': thinkingEffort,
          'contextWindowSize': contextWindowSize,
        }),
      ),
    );
  }
}
