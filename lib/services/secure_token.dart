import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全令牌存储：使用 Android Keystore / iOS Keychain 加密存储，
/// APK 解包无法读取（不同于 --dart-define / 硬编码 / .env）。
///
/// 首次启动时，令牌通过构建参数注入，立即迁移到安全存储。
/// 构建命令：
///   flutter build apk --dart-define=INIT_GITEE_TOKEN=your_token
class SecureToken {
  SecureToken._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'gitee_pat';

  /// 读取 Gitee PAT。优先从安全存储读取；首次启动时从构建参数注入后
  /// 立即迁移。
  static Future<String?> getGiteeToken() async {
    // 1. 安全存储优先
    var token = await _storage.read(key: _key);
    if (token != null && token.isNotEmpty) return token;

    // 2. 首次启动：从构建参数注入并迁移到安全存储
    // ignore: invalid_use_of_visible_for_testing_member
    const injected = String.fromEnvironment('INIT_GITEE_TOKEN');
    if (injected.isNotEmpty) {
      await _storage.write(key: _key, value: injected);
      debugPrint('[SecureToken] 已迁移构建参数到安全存储');
      return injected;
    }

    return null;
  }
}
