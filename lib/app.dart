import 'package:flutter/material.dart';
import 'core/agent_colors.dart';
import 'screens/chat_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final light = AgentColors.light();
    final dark = AgentColors.dark();

    return MaterialApp(
      title: 'Personal Agent',
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
      themeMode: ThemeMode.light,
      home: const ChatScreen(),
    );
  }
}
