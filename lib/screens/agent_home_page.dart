import 'package:flutter/material.dart';

import 'agent_contact_page.dart';
import 'message_list_page.dart';
import '../widgets/agent_bottom_nav.dart';

/// Agent 首页（微信风格，统一胶囊底栏）。
class AgentHomePage extends StatefulWidget {
  const AgentHomePage({super.key});

  @override
  State<AgentHomePage> createState() => _AgentHomePageState();
}

class _AgentHomePageState extends State<AgentHomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0
          ? const MessageListPage()
          : const AgentContactPage(),
      bottomNavigationBar: AgentBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
