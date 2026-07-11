import 'package:package_info_plus/package_info_plus.dart';

/// 应用级配置。版本号从 pubspec.yaml 运行时读取，无需手动同步。
class AppConfig {
  AppConfig._();

  static String _version = '1.4.24';
  static String _buildNumber = '20';

  /// 当前应用版本号（来自 pubspec.yaml 的 version 字段）。
  static String get version => _version;

  /// 显示用版本号（带 v 前缀）。
  static String get displayVersion => 'v$_version';

  /// 构建号。
  static String get buildNumber => _buildNumber;

  static const String appName = 'DWeis';

  /// 应用启动时调用，从平台读取真实版本号。
  static Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    _version = info.version;
    _buildNumber = info.buildNumber;
  }
}
