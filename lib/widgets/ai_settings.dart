import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import '../services/crypto_util.dart';
import '../services/log_service.dart';
import '../services/secure_storage.dart';
import 'vendor_config.dart';

/// AI 设置管理器
class AISettings extends ChangeNotifier {
  AISettings();

  List<(String, String, String)> _builtIn = [];
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
    String agnesKey;
    try {
      agnesKey = CryptoUtil.decrypt(dotenv.env['AGNES_API_KEY'] ?? '');
    } catch (_) {
      // dotenv 未初始化（.env 文件缺失或加载失败）→ 内置模型不可用但应用不崩溃
      return;
    }
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
      final defaultModel = id == 'Agnes-2.0-Flash' ? 'agnes-2.0-flash' : '';
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
    SecureStorage().delete('vendor_key_$id');
    if (selectedVendorId == id) {
      selectedVendorId = vendors.isNotEmpty ? vendors.first.id : null;
    }
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

        // 迁移：从 JSON 读入的 API key 写入 SecureStorage，之后 JSON 不再含 key
        bool migrated = false;
        final storage = SecureStorage();
        for (final v in vendors) {
          if (v.apiKey.isNotEmpty) {
            try {
              final existing =
                  await storage.read('vendor_key_${v.id}');
              if (existing == null || existing.isEmpty) {
                await storage.write('vendor_key_${v.id}', v.apiKey);
                migrated = true;
              }
            } catch (_) { /* SecureStorage 不可用 */ }
          }
        }
        if (migrated) await save(); // 重写 JSON（不含 apiKey）
      }
    } catch (e) {
      log.w('AISettings', '加载AI设置失败: $e');
    }
    _ensureBuiltIn();
    // 恢复 SecureStorage 中的 API key 到内存对象
    await _restoreKeys();
    if (selectedVendorId == null && vendors.isNotEmpty) {
      selectVendor(vendors.first.id);
    }
    _loaded = true;
    notifyListeners();
  }

  /// 将 SecureStorage 中的 API key 恢复到内存 [vendors] 对象中。
  Future<void> _restoreKeys() async {
    final storage = SecureStorage();
    for (int i = 0; i < vendors.length; i++) {
      final v = vendors[i];
      try {
        final key = await storage.read('vendor_key_${v.id}');
        if (key != null && key.isNotEmpty) {
          vendors[i] = v.copyWith(apiKey: key);
        }
      } catch (_) { /* SecureStorage 不可用 */ }
    }
  }

  Future<void> save() async {
    final storage = SecureStorage();
    // API key 存 SecureStorage，JSON 不含 key
    for (final v in vendors) {
      if (v.apiKey.isNotEmpty) {
        try {
          await storage.write('vendor_key_${v.id}', v.apiKey);
        } catch (_) { /* SecureStorage 不可用 */ }
      }
    }
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
    notifyListeners();
  }
}
