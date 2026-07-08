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

  TextTheme _buildTextTheme(Color textColor) {
    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: textColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: textColor,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: textColor,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: textColor,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: textColor,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: textColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: textColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: textColor,
      ),
      bodySmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: textColor,
      ),
      labelLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: textColor,
      ),
      labelMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: textColor,
      ),
      labelSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.2,
        color: textColor,
      ),
    );
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

    final textTheme = _buildTextTheme(agentColors.textPrimary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: agentColors.background,
      textTheme: textTheme,
      fontFamily: '-apple-system',
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        // Apple HIG：导航栏毛玻璃材质，半透明背景
        backgroundColor: agentColors.background.withValues(alpha: 0.85),
        foregroundColor: agentColors.textPrimary,
        titleTextStyle: textTheme.titleLarge,
        // Apple HIG：0.5px 底部分隔线
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: agentColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          // Apple HIG：按钮圆角 12px
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: agentColors.primary,
          side: BorderSide(color: agentColors.divider),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: agentColors.primary,
          textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: agentColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: agentColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: agentColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: agentColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: agentColors.error),
        ),
        labelStyle: TextStyle(color: agentColors.textSecondary),
        hintStyle: TextStyle(color: agentColors.textDisabled),
      ),
      dividerTheme: DividerThemeData(
        color: agentColors.divider,
        thickness: 0.5,
        space: 0.5,
      ),
      cardTheme: CardThemeData(
        color: agentColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.zero,
      ),
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
