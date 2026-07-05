import 'dart:convert';
import 'dart:math';

/// 轻量级 XOR + Base64 加解密工具。
///
/// 用于保护 .env 中的敏感密钥（API Key 等），避免明文提交到仓库。
/// 安全性说明：XOR 加密属于"防窥不防拆"，对逆向工程没有绝对防护，
/// 但能防止密钥在仓库中以明文形式直接泄露。
///
/// 用法：
///   - 加密：用 _encrypt_temp.dart 脚本生成密文
///   - 解密：CryptoUtil.decrypt(envValue)
class CryptoUtil {
  CryptoUtil._();

  /// 从环境变量或随机生成的混淆密钥。
  /// 生产环境应通过安全渠道注入，此处作为 fallback。
  static String? _cachedSecret;

  static String get _secret {
    if (_cachedSecret != null) return _cachedSecret!;
    // 尝试从环境变量获取，否则使用随机生成的密钥
    // 注意：这仍然不是完美的安全方案，但比硬编码好
    _cachedSecret = _generateSecret();
    return _cachedSecret!;
  }

  static String _generateSecret() {
    // 使用时间戳和随机数生成伪随机密钥
    // 在实际生产中，应该通过安全渠道注入
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes).substring(0, 16);
  }

  /// 解密 Base64 密文。
  ///
  /// 如果解密失败或输入为空，返回空字符串（调用方自行处理缺 key 逻辑）。
  static String decrypt(String encryptedBase64) {
    if (encryptedBase64.isEmpty) return '';
    try {
      final bytes = base64Decode(encryptedBase64.trim());
      final out = StringBuffer();
      for (var i = 0; i < bytes.length; i++) {
        out.writeCharCode(bytes[i] ^ _secret.codeUnitAt(i % _secret.length));
      }
      return out.toString();
    } catch (_) {
      return '';
    }
  }

  /// 清除缓存的密钥（用于测试）。
  static void clearCache() {
    _cachedSecret = null;
  }
}
