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

  /// 应用级混淆密钥。优先从构建参数读取，无法获取时用硬编码兜底。
  /// 构建: flutter build apk --dart-define=XOR_SECRET=your_key
  static String get _secret {
    // ignore: invalid_use_of_visible_for_testing_member
    const fromBuild = String.fromEnvironment('XOR_SECRET');
    if (fromBuild.isNotEmpty) return fromBuild;
    return 'DWeisApp2026';
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

  /// 加密明文为 Base64 密文。与 [decrypt] 互逆。
  ///
  /// 用于运行时持久化敏感信息（如 MCP 服务器 API Key）。
  static String encrypt(String plain) {
    if (plain.isEmpty) return '';
    final bytes = <int>[];
    for (var i = 0; i < plain.length; i++) {
      bytes.add(plain.codeUnitAt(i) ^ _secret.codeUnitAt(i % _secret.length));
    }
    return base64Encode(bytes);
  }
}
