import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/app_config.dart';
import 'core/error_handler.dart';
import 'core/service_locator.dart';
import 'services/connectivity_service.dart';
import 'services/log_service.dart';
import 'services/foreground_service.dart';
import 'services/storage/app_database.dart';
import 'services/storage/db_migration.dart';
import 'services/tts_service_config.dart';
import 'services/token_usage_tracker.dart';
import 'tools/plugin_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorHandler.init();
  ErrorWidget.builder = ErrorHandler.buildErrorWidget;
  // 默认开启文件日志（崩溃留痕 + 问题排查），设置里可手动关闭
  await log.setEnabled(true);
  await configureDependencies();

  // 初始化 SQLite 数据库（建表等），必须早于任何 storage 读写
  try {
    await AppDatabase.instance.initialize();
  } catch (e) {
    debugPrint('数据库初始化失败: $e');
    // 即使数据库初始化失败也不阻塞（某些平台可能不支持 sqflite）
  }

  // 从旧 JSON 文件迁移数据到 SQLite（须 await 等迁移完成再启动 app，
  // 否则 CachedRepository 会缓存空数据导致 UI 永远不刷新）
  try {
    await DbMigration.run();
  } catch (e) {
    debugPrint('数据库迁移失败: $e');
  }

  // 加载语音服务配置并接线工厂（多厂商 TTS 切换，不阻塞首屏）
  try {
    await TtsServiceConfig.instance.load();
    TtsServiceConfig.instance.wire();
  } catch (e) {
    debugPrint('语音服务配置加载失败: $e');
  }

  // 加载 token 用量统计（按厂商+模型核算成本，不阻塞首屏）
  try {
    await tokenTracker.load();
  } catch (e) {
    debugPrint('token 用量加载失败: $e');
  }

    await runZonedGuarded(() async {
    await dotenv.load();
    await AppConfig.init();
    await getIt<ConnectivityService>().init();

    // 启动前台服务，保持应用在后台运行（均不阻塞首屏冷启动）
    unawaited(ForegroundService.start());

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
    runApp(const App());

    // MCP 插件初始化（连接服务器 + 拉工具列表）移到 runApp 之后，
    // 不阻塞首屏展示。用户看到界面期间后台静默连接。
    unawaited(PluginRegistry.instance.init());
  }, ErrorHandler.logError);
}
