import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'log_service.dart';

/// Linux 沙箱服务
///
/// 基于 PRoot + Alpine Linux，在 Android 上运行 Linux 环境。
class SandboxService {
  static final SandboxService _instance = SandboxService._();
  factory SandboxService() => _instance;
  SandboxService._();

  SandboxState _state = SandboxState.idle;
  SandboxState get state => _state;

  String? _rootDir;
  String? get rootDir => _rootDir;

  String? _prootBinary;
  Duration commandTimeout = const Duration(seconds: 60);

  final _stateController = StreamController<SandboxState>.broadcast();
  Stream<SandboxState> get stateStream => _stateController.stream;

  /// 初始化沙箱
  Future<bool> init({String? customRootDir}) async {
    if (_state == SandboxState.ready) return true;
    _updateState(SandboxState.initializing);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _rootDir = customRootDir ?? '${appDir.path}/sandbox';

      final root = Directory(_rootDir!);
      if (!await root.exists()) await root.create(recursive: true);

      _prootBinary = await _ensureProot();
      await _ensureAlpineRootfs();

      _updateState(SandboxState.ready);
      log.i('Sandbox', '沙箱初始化完成: $_rootDir');
      return true;
    } catch (e) {
      log.e('Sandbox', '初始化失败', e);
      _updateState(SandboxState.error);
      return false;
    }
  }

  /// 执行命令
  Future<SandboxResult> execute(
    String command, {
    String? workingDir,
    Duration? timeout,
  }) async {
    if (_state != SandboxState.ready) {
      return SandboxResult(exitCode: -1, stdout: '', stderr: '沙箱未就绪');
    }

    final effectiveTimeout = timeout ?? commandTimeout;
    final effectiveWorkDir = workingDir ?? '/root';

    try {
      final args = [
        '-0',
        '-r', '$_rootDir/rootfs',
        '-w', effectiveWorkDir,
        '-b', '/proc',
        '-b', '/sys',
        '-b', '/dev',
        '-b', '/tmp',
        '--',
        '/bin/sh', '-c', command,
      ];

      final process = await Process.start(
        _prootBinary!,
        args,
        workingDirectory: _rootDir,
        environment: {
          'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
          'HOME': '/root',
          'TERM': 'xterm-256color',
          'LANG': 'en_US.UTF-8',
        },
      );

      final stdout = StringBuffer();
      final stderr = StringBuffer();

      final timer = Timer(effectiveTimeout, () {
        process.kill(ProcessSignal.sigterm);
      });

      process.stdout.listen((data) {
        stdout.write(utf8.decode(data, allowMalformed: true));
      });

      process.stderr.listen((data) {
        stderr.write(utf8.decode(data, allowMalformed: true));
      });

      final exitCode = await process.exitCode;
      timer.cancel();

      return SandboxResult(
        exitCode: exitCode,
        stdout: stdout.toString(),
        stderr: stderr.toString(),
      );
    } catch (e) {
      return SandboxResult(exitCode: -1, stdout: '', stderr: '执行失败: $e');
    }
  }

  /// 关闭沙箱
  Future<void> close() async {
    _updateState(SandboxState.closing);
    _updateState(SandboxState.idle);
  }

  Future<String> _ensureProot() async {
    final prootPath = '$_rootDir/proot';
    final prootFile = File(prootPath);

    if (!await prootFile.exists()) {
      log.i('Sandbox', '下载 PRoot...');
      // TODO: 实际下载 PRoot 二进制
      // 当前返回路径，需要预先准备好二进制文件
      throw UnsupportedError(
        'PRoot 二进制未找到。请将 proot-aarch64 放置到 $_rootDir/proot'
      );
    }

    // 确保可执行
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', prootPath]);
    }

    return prootPath;
  }

  Future<void> _ensureAlpineRootfs() async {
    final rootfsDir = Directory('$_rootDir/rootfs');
    if (await rootfsDir.exists()) return;

    log.i('Sandbox', '解压 Alpine rootfs...');
    // TODO: 实际下载并解压 Alpine rootfs
    throw UnsupportedError(
      'Alpine rootfs 未找到。请将 alpine-rootfs.tar.gz 解压到 $_rootDir/rootfs'
    );
  }

  void _updateState(SandboxState newState) {
    _state = newState;
    _stateController.add(newState);
  }
}

enum SandboxState { idle, initializing, ready, closing, error }

class SandboxResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  const SandboxResult({required this.exitCode, required this.stdout, required this.stderr});
  bool get isSuccess => exitCode == 0;
}
