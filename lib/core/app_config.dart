/// 应用级配置常量。修改版本号时请同步更新 pubspec.yaml 的 version 字段。
class AppConfig {
  AppConfig._();

  /// 当前应用版本号，与 pubspec.yaml version 字段保持一致。
  static const String version = '0.6.6';

  /// 显示用版本号（带 v 前缀）。
  static const String displayVersion = 'v$version';

  static const String appName = 'DWeis';
}
