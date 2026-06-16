import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateService {
  static const String _repoOwner = '3d-jq';
  static const String _repoName = 'personal-agent-app';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  /// 检查是否有新版本
  static Future<UpdateInfo?> checkUpdate(String currentVersion) async {
    try {
      final dio = Dio();
      final resp = await dio.get(
        _apiUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );

      if (resp.statusCode != 200) return null;

      final tagName = resp.data['tag_name'] as String? ?? '';
      final latestVersion = tagName.replaceFirst('v', '');
      final notes = resp.data['body'] as String? ?? '';
      final htmlUrl = resp.data['html_url'] as String? ?? '';

      // 解析 APK 下载链接：优先用 .env 里配置的 UPDATE_APK_URL
      String? apkUrl = dotenv.env['UPDATE_APK_URL'];
      if (apkUrl == null || apkUrl.isEmpty) {
        final assets = resp.data['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      // 比较版本号
      if (_compareVersion(latestVersion, currentVersion) > 0) {
        return UpdateInfo(
          version: latestVersion,
          notes: notes,
          htmlUrl: htmlUrl,
          apkUrl: apkUrl,
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 下载 APK
  static Future<String?> downloadApk(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      // 请求存储权限
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final manageStatus = await Permission.manageExternalStorage.request();
          if (!manageStatus.isGranted) {
            return null;
          }
        }
      }

      final dio = Dio();
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/app-update.apk';

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received, total);
          }
        },
      );

      return savePath;
    } catch (e) {
      return null;
    }
  }

  /// 安装 APK
  static Future<bool> installApk(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      return result.type == ResultType.done;
    } catch (e) {
      return false;
    }
  }

  /// 比较版本号
  /// 返回: 1 表示 v1 > v2, 0 表示相等, -1 表示 v1 < v2
  static int _compareVersion(String v1, String v2) {
    final parts1 = v1.split('.').map(int.tryParse).whereType<int>().toList();
    final parts2 = v2.split('.').map(int.tryParse).whereType<int>().toList();

    for (var i = 0; i < parts1.length || i < parts2.length; i++) {
      final a = i < parts1.length ? parts1[i] : 0;
      final b = i < parts2.length ? parts2[i] : 0;
      if (a > b) return 1;
      if (a < b) return -1;
    }
    return 0;
  }
}

class UpdateInfo {
  final String version;
  final String notes;
  final String htmlUrl;
  final String? apkUrl;

  UpdateInfo({
    required this.version,
    required this.notes,
    required this.htmlUrl,
    this.apkUrl,
  });
}
