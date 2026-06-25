import 'package:flutter/material.dart';
import 'core/agent_colors.dart';
import 'core/service_locator.dart';
import 'screens/chat_screen.dart';
import 'services/theme_service.dart';
import 'widgets/ai_settings_sheet.dart';
import 'widgets/onboarding_page.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _themeService = getIt<ThemeService>();
  bool _loaded = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    final aiSettings = getIt<AISettings>();
    _themeService.load().then((_) async {
      await aiSettings.load();
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _showOnboarding = !aiSettings.hasVendor;
      });
    });
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seed = _themeService.seedColor;
    final lightScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    final darkScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

    return MaterialApp(
      title: 'DWeis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: lightScheme,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
          titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3),
          labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.2),
        ),
        appBarTheme: const AppBarTheme(elevation: 0, scrolledUnderElevation: 0),
        extensions: [AgentColors.fromScheme(lightScheme)],
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: darkScheme,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
          titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3),
          labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.2),
        ),
        appBarTheme: const AppBarTheme(elevation: 0, scrolledUnderElevation: 0),
        extensions: [AgentColors.fromScheme(darkScheme)],
      ),
      themeMode: _loaded ? _themeService.mode : ThemeMode.light,
      home: _showOnboarding
          ? OnboardingPage(
              onComplete: () => setState(() => _showOnboarding = false),
            )
          : const ChatScreen(),
    );
  }
}
