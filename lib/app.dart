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

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final agentColors = isDark ? AgentColors.dark() : AgentColors.light();
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: agentColors.primary,
      onPrimary: Colors.white,
      secondary: agentColors.primary,
      onSecondary: Colors.white,
      error: agentColors.error,
      onError: Colors.white,
      surface: agentColors.surface,
      onSurface: agentColors.textPrimary,
      outline: agentColors.divider,
      outlineVariant: agentColors.divider,
      surfaceContainerHighest: agentColors.primarySurface,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: agentColors.background,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
      appBarTheme: const AppBarTheme(elevation: 0, scrolledUnderElevation: 0),
      extensions: [agentColors],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DWeis',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _loaded ? _themeService.mode : ThemeMode.light,
      home: _showOnboarding
          ? OnboardingPage(
              onComplete: () => setState(() => _showOnboarding = false),
            )
          : const ChatScreen(),
    );
  }
}
