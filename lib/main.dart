import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/app_config.dart';
import 'core/error_handler.dart';
import 'core/service_locator.dart';
import 'services/connectivity_service.dart';
import 'services/foreground_service.dart';
import 'services/mcp_manager.dart';
import 'tools/skill_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorHandler.init();
  ErrorWidget.builder = ErrorHandler.buildErrorWidget;
  configureDependencies();

  await runZonedGuarded(() async {
    await dotenv.load();
    await AppConfig.init();
    await getIt<ConnectivityService>().init();

    // 加载已持久化的自定义 Skill 和激活状态，再注册内置 Skill
    final skillRegistry = getIt<SkillRegistry>();
    await skillRegistry.loadFromDisk();
    skillRegistry.registerBuiltInSkills();

    // 自动连接所有已启用的 MCP 服务器（失败不阻塞启动）
    await getIt<McpManager>().autoConnect();

    // 启动前台服务，保持应用在后台运行
    await ForegroundService.start();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
    runApp(const App());
  }, ErrorHandler.logError);
}
