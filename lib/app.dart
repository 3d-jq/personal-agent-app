import 'package:flutter/material.dart';
import 'core/agent_colors.dart';
import 'screens/chat_screen.dart';
import 'services/theme_service.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _themeService = ThemeService();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(() => setState(() {}));
    _themeService.load().then((_) => setState(() => _loaded = true));
  }

  @override
  Widget build(BuildContext context) {
    final light = AgentColors.light();
    final dark = AgentColors.dark();

    return MaterialApp(
      title: 'DWeis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: light.background,
        colorScheme: ColorScheme.light(
          primary: light.textPrimary,
          surface: light.surface,
          onPrimary: light.background,
          onSurface: light.textPrimary,
          outline: light.divider,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: light.background,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        extensions: [light],
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: dark.background,
        colorScheme: ColorScheme.dark(
          primary: dark.textPrimary,
          surface: dark.surface,
          onPrimary: dark.background,
          onSurface: dark.textPrimary,
          outline: dark.divider,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: dark.background,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        extensions: [dark],
      ),
      themeMode: _loaded ? _themeService.mode : ThemeMode.light,
      home: const ChatScreen(),
    );
  }
}
