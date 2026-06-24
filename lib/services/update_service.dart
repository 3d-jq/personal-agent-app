import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// 更新过程中的错误信息。
///
/// [type] 用于在 UI 上给出更准确的提示，[reason] 是底层真实异常文本（可记录日志）。
class UpdateException implements Exception {
  final UpdateErrorType type;
  final String reason;
  UpdateException(this.type, [this.reason = '']);

  @override
  String toString() => 'UpdateException($type): $reason';
}

enum UpdateErrorType {
  /// 网络/服务端异常（重定向、超时、HTTP 非 200 等）
  network,

  /// 写文件失败（磁盘满、IO 错误等）
  io,

  /// 解析返回数据失败（JSON 结构异常等）
  parse,

  /// 其它未分类错误
  unknown,
}

class UpdateService {
  // 仓库托管在 Gitee（GitHub 上没有此仓库，此前用 GitHub API 永远查不到更新）。
  static const String _giteeOwner = 'deng-6669';
  static const String _giteeRepo = 'personal-agent-app';
  static const String _apiUrl =
      'https://gitee.com/api/v5/repos/$_giteeOwner/$_giteeRepo/releases/latest';

  /// 检查是否有新版本。
  ///
  /// 失败时抛出 [UpdateException]，调用方应捕获并展示真实原因，
  /// 而不是统一显示"请检查网络连接或存储权限"。
  static Future<UpdateInfo?> checkUpdate(String currentVersion) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    try {
      final resp = await dio.get(
        _apiUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/json'},
        ),
      );

      if (resp.statusCode != 200) {
        throw UpdateException(
          UpdateErrorType.network,
          'GitHub API 返回 ${resp.statusCode}',
        );
      }

      final tagName = resp.data['tag_name'] as String? ?? '';
      final latestVersion = tagName.replaceFirst('v', '');
      final notes = resp.data['body'] as String? ?? '';
      // Gitee 的 release 接口顶层无 html_url，自行拼接 release 页地址。
      final htmlUrl =
          resp.data['html_url'] as String? ??
          'https://gitee.com/$_giteeOwner/$_giteeRepo/releases/tag/$tagName';

      // 解析 APK 下载链接
      String? apkUrl = dotenv.env['UPDATE_APK_URL'] ?? '';
      if (apkUrl.isNotEmpty) {
        // 用最新版本号替换链接中的版本占位符
        apkUrl = apkUrl.replaceAll('{version}', latestVersion);
      } else {
        // 从 GitHub asset 获取
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
    } on DioException catch (e) {
      throw UpdateException(UpdateErrorType.network, _dioReason(e));
    } on UpdateException {
      rethrow;
    } catch (e) {
      throw UpdateException(UpdateErrorType.parse, e.toString());
    }
  }

  /// 下载 APK。
  ///
  /// 注意：本方法把 APK 写入应用私有临时目录（getTemporaryDirectory），
  /// 该目录属于应用沙箱，Android 上**无需任何存储权限**即可读写。
  /// 因此这里不再请求 Permission.storage / manageExternalStorage——
  /// 它们在 Android 11+ 上往往直接被拒，反而成为"下载失败"的根因。
  ///
  /// 失败时抛出 [UpdateException]，调用方应展示真实原因。
  static Future<String> downloadApk(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
    try {
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
        options: Options(
          // Gitee / GitHub 的下载链接会经过多次 302 重定向，dio 默认会跟随，
          // 这里显式声明一下，避免被某些拦截器误改。
          followRedirects: true,
          maxRedirects: 8,
          receiveTimeout: const Duration(minutes: 10),
        ),
        deleteOnError: true,
      );

      final file = File(savePath);
      if (!await file.exists() || await file.length() < 1024) {
        throw UpdateException(UpdateErrorType.network, '下载文件为空或过小');
      }

      return savePath;
    } on UpdateException {
      rethrow;
    } on DioException catch (e) {
      throw UpdateException(UpdateErrorType.network, _dioReason(e));
    } catch (e) {
      throw UpdateException(UpdateErrorType.io, e.toString());
    }
  }

  /// 把 DioException 转成一句人类可读的中文原因。
  static String _dioReason(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时';
      case DioExceptionType.receiveTimeout:
        return '下载超时';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        return '服务器返回错误$code';
      case DioExceptionType.connectionError:
        return '无法连接服务器（网络不通或被拦截）';
      case DioExceptionType.cancel:
        return '下载被取消';
      default:
        return e.message ?? e.type.name;
    }
  }

  /// 安装 APK
  static Future<bool> installApk(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      return result.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }

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

  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.htmlUrl,
    this.apkUrl,
  });
}
