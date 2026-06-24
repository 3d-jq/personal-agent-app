import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/app_config.dart';
import 'core/error_handler.dart';
import 'core/service_locator.dart';
import 'services/connectivity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorHandler.init();
  ErrorWidget.builder = ErrorHandler.buildErrorWidget;
  configureDependencies();

  await runZonedGuarded(() async {
    await dotenv.load();
    await AppConfig.init();
    await getIt<ConnectivityService>().init();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
    runApp(const App());
  }, ErrorHandler.logError);
}
