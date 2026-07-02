import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final poppins = GoogleFonts.poppins(color: textColor);
    final lora = GoogleFonts.lora(color: textColor);
    return TextTheme(
      headlineLarge: poppins.copyWith(fontSize: 28, fontWeight: FontWeight.w500, height: 1.2),
      headlineMedium: poppins.copyWith(fontSize: 22, fontWeight: FontWeight.w500, height: 1.3),
      headlineSmall: poppins.copyWith(fontSize: 20, fontWeight: FontWeight.w500, height: 1.3),
      titleLarge: poppins.copyWith(fontSize: 18, fontWeight: FontWeight.w500, height: 1.3),
      titleMedium: poppins.copyWith(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
      titleSmall: poppins.copyWith(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
      bodyLarge: lora.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.7),
      bodyMedium: lora.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.7),
      bodySmall: lora.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.6),
      labelLarge: poppins.copyWith(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3),
      labelMedium: poppins.copyWith(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3),
      labelSmall: poppins.copyWith(fontSize: 11, fontWeight: FontWeight.w500, height: 1.2, letterSpacing: 0.1),
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
      fontFamily: GoogleFonts.lora().fontFamily,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: agentColors.background,
        foregroundColor: agentColors.textPrimary,
        titleTextStyle: textTheme.titleLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: agentColors.primary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: agentColors.divider),
          ),
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(agentColors.primary.withValues(alpha: 0.08)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: agentColors.primary,
          side: BorderSide(color: agentColors.divider),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(agentColors.primary.withValues(alpha: 0.08)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: agentColors.primary,
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: UnderlineInputBorder(borderSide: BorderSide(color: agentColors.divider)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: agentColors.divider)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: agentColors.primary, width: 1.5)),
        errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: agentColors.error)),
        labelStyle: textTheme.bodyMedium?.copyWith(color: agentColors.textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: agentColors.textDisabled),
      ),
      dividerTheme: DividerThemeData(
        color: agentColors.divider,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: agentColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: agentColors.divider),
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
