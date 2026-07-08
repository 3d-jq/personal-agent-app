import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../widgets/common_widgets.dart';
import 'mcp_manage_page.dart';
import 'skill_manage_page.dart';

/// Skill & MCP 管理页面（包含两个 Tab）
class SkillMcpPage extends StatefulWidget {
  const SkillMcpPage({super.key});

  @override
  State<SkillMcpPage> createState() => _SkillMcpPageState();
}

class _SkillMcpPageState extends State<SkillMcpPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppTopBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: nc.textPrimary, size: 22),
          onPressed: () => Navigator.pop(context),
          tooltip: '返回',
        ),
        title: 'Skill & MCP',
        bottom: TabBar(
          controller: _tabController,
          labelColor: nc.primary,
          unselectedLabelColor: nc.textSecondary,
          indicatorColor: nc.primary,
          tabs: const [
            Tab(text: 'Skill'),
            Tab(text: 'MCP'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SkillManagePage(),
          McpManagePage(),
        ],
      ),
    );
  }
}
