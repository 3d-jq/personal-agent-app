import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'secure_token.dart';

class UpdateException implements Exception {
  final String reason;
  const UpdateException([this.reason = '']);
  @override
  String toString() => 'UpdateException: $reason';
}

class UpdateInfo {
  final String version;
  final String notes;
  final String? apkUrl;

  const UpdateInfo({
    required this.version,
    this.notes = '',
    this.apkUrl,
  });
}

/// 版本更新服务：
/// - checkUpdate(): 比对远端 latest.json → 返回 UpdateInfo 或 null
/// - downloadApk(): 下载 APK（支持进度回调）
/// - installApk(): 调系统安装器安装
class UpdateService {
  UpdateService._();

  /// 远端 latest.json URL。
  /// 优先从 dart-define 读取，否则用 Gitee Release 默认地址。
  static String get _remoteUrl {
    const env = String.fromEnvironment('UPDATE_URL');
    if (env.isNotEmpty) return env;
    return 'https://gitee.com/3d-jq/personal_agent_app/raw/main/latest.json';
  }

  /// 检查更新。返回可用更新，或 null（已最新）。
  /// 抛出 [UpdateException] 时表示网络/解析错误。
  static Future<UpdateInfo?> checkUpdate(String currentVersion) async {
    try {
      final token = await SecureToken.getGiteeToken();
      if (token == null) return null; // 无令牌，跳过检查

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final resp = await dio.get(
        _remoteUrl,
        queryParameters: {'access_token': token},
      );
      if (resp.statusCode != 200) {
        throw UpdateException('服务器返回 ${resp.statusCode}');
      }

      final data = resp.data as Map<String, dynamic>;
      final remoteVersion = data['version'] as String?;
      final downloadUrl = data['apk_url'] as String?;
      final notes = data['release_notes'] as String?;

      if (remoteVersion == null || downloadUrl == null) {
        throw UpdateException('更新信息格式错误');
      }

      // 版本号比较：简单字符串按 . 拆分比较
      if (!_isNewer(currentVersion, remoteVersion)) return null;

      return UpdateInfo(
        version: remoteVersion,
        apkUrl: downloadUrl,
        notes: notes ?? '',
      );
    } on UpdateException {
      rethrow;
    } on DioException catch (e) {
      throw UpdateException('网络错误: ${e.message}');
    } catch (e) {
      throw UpdateException('$e');
    }
  }

  /// 下载 APK 到外部存储，返回本地路径。
  /// [onProgress] 回调 `(received, total)`。
  static Future<String> downloadApk(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dio = Dio();
    final dir = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/app_update.apk');

    // 如果已有旧下载文件，先删除
    if (await file.exists()) await file.delete();

    await dio.download(url, file.path, onReceiveProgress: onProgress);
    return file.path;
  }

  /// 调起系统安装器。
  static Future<bool> installApk(String filePath) async {
    final result = await OpenFilex.open(filePath,
        type: 'application/vnd.android.package-archive');
    return result.type == ResultType.done;
  }

  /// 语义化版本比较：remote > current → true
  static bool _isNewer(String current, String remote) {
    final cv = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final rv = remote.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final len = cv.length > rv.length ? cv.length : rv.length;
    for (var i = 0; i < len; i++) {
      final c = i < cv.length ? cv[i] : 0;
      final r = i < rv.length ? rv[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }
}
