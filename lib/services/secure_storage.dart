import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Android Keystore / iOS Keychain 安全存储包装。
///
/// 替代旧的 XOR+硬编码密钥方案，用于存储 API keys 等敏感信息。
/// 用法：`getIt<SecureStorage>()` 或直接 `SecureStorage.instance`。
class SecureStorage {
  static final SecureStorage _instance = SecureStorage._();
  factory SecureStorage() => _instance;
  SecureStorage._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();
}
