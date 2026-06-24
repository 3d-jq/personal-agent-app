import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/app_config.dart';
import 'core/error_handler.dart';
import 'services/connectivity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorHandler.init();
  ErrorWidget.builder = ErrorHandler.buildErrorWidget;

  await runZonedGuarded(() async {
    await dotenv.load();
    await AppConfig.init();
    await ConnectivityService().init();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
      ),
    );
    runApp(const App());
  }, ErrorHandler.logError);
}
