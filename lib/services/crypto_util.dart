import 'dart:convert';

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

  /// 应用级固定混淆密钥。修改此处需重新加密所有 .env 中的值。
  static const String _secret = 'DWeisApp2026';

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
}
