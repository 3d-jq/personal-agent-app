import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/agent_colors.dart';
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
      appBar: AppBar(
        backgroundColor: nc.background.withValues(alpha: 0.85),
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIconsRegular.arrowLeft, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Skill & MCP',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: nc.textPrimary,
          ),
        ),
        centerTitle: true,
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
