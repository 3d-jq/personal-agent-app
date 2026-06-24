import 'package:flutter/material.dart';
import 'core/agent_colors.dart';
import 'core/app_animations.dart';
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

class _AppState extends State<App> with SingleTickerProviderStateMixin {
  final _themeService = getIt<ThemeService>();
  bool _loaded = false;
  bool _showOnboarding = false;

  late AnimationController _themeAnimCtrl;
  late Animation<Color?> _bgColorAnim;

  @override
  void initState() {
    super.initState();
    _themeAnimCtrl = AnimationController(vsync: this, duration: AppDurations.slow);
    _bgColorAnim = ColorTween(begin: animatedBgNotifier.value, end: animatedBgNotifier.value).animate(
      CurvedAnimation(parent: _themeAnimCtrl, curve: AppCurves.color),
    );
    _themeAnimCtrl.addListener(() {
      animatedBgNotifier.value = _bgColorAnim.value ?? animatedBgNotifier.value;
    });

    _themeService.addListener(_onThemeChanged);
    final aiSettings = getIt<AISettings>();
    _themeService.load().then((_) async {
      await aiSettings.load();
      if (!mounted) return;
      _syncBgColor();
      setState(() {
        _loaded = true;
        _showOnboarding = !aiSettings.hasVendor;
      });
    });
  }

  Color get _targetBgColor {
    final isDark = _themeService.mode == ThemeMode.dark ||
        (_themeService.mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return isDark ? AgentColors.dark().staticBackground : AgentColors.light().staticBackground;
  }

  void _syncBgColor() {
    final target = _targetBgColor;
    _bgColorAnim = ColorTween(begin: target, end: target).animate(_themeAnimCtrl);
    animatedBgNotifier.value = target;
  }

  void _onThemeChanged() {
    final newColor = _targetBgColor;
    final oldColor = animatedBgNotifier.value;
    _bgColorAnim = ColorTween(begin: oldColor, end: newColor).animate(
      CurvedAnimation(parent: _themeAnimCtrl, curve: AppCurves.color),
    );
    _themeAnimCtrl.forward(from: 0.0);
    setState(() {});
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _themeAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final light = AgentColors.light();
    final dark = AgentColors.dark();
    final currentBg = animatedBgNotifier.value;

    return AnimatedBuilder(
      animation: animatedBgNotifier,
      builder: (context, _) {
        final bg = animatedBgNotifier.value;
        return MaterialApp(
          title: 'DWeis',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.light(
              primary: light.textPrimary,
              surface: light.surface,
              onPrimary: bg,
              onSurface: light.textPrimary,
              outline: light.divider,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: bg,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            extensions: [light],
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.dark(
              primary: dark.textPrimary,
              surface: dark.surface,
              onPrimary: bg,
              onSurface: dark.textPrimary,
              outline: dark.divider,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: bg,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            extensions: [dark],
          ),
          themeMode: _loaded ? _themeService.mode : ThemeMode.light,
          home: _showOnboarding
              ? OnboardingPage(onComplete: () => setState(() => _showOnboarding = false))
              : const ChatScreen(),
        );
      },
    );
  }
}
