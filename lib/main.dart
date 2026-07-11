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

  await runZonedGuarded(() async {
    await dotenv.load();
    await AppConfig.init();
    await getIt<ConnectivityService>().init();

    // 统一初始化能力插件：加载自定义/内置 Skill、自动连接已启用的 MCP 服务器。
    // （内置插件清单在 configureDependencies 中注册，此处执行一次性副作用。）
    await PluginRegistry.instance.init();

    // 启动前台服务，保持应用在后台运行（均不阻塞首屏冷启动）
    unawaited(ForegroundService.start());

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
    runApp(const App());
  }, ErrorHandler.logError);
}
