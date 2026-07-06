import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/agent_colors.dart';
import '../core/service_locator.dart';
import '../tools/skill_registry.dart';
import '../tools/skill_manage_tool.dart';

/// Skill 管理页面
class SkillManagePage extends StatefulWidget {
  const SkillManagePage({super.key});

  @override
  State<SkillManagePage> createState() => _SkillManagePageState();
}

class _SkillManagePageState extends State<SkillManagePage> {
  late final SkillRegistry _skillRegistry;

  @override
  void initState() {
    super.initState();
    _skillRegistry = getIt<SkillRegistry>();
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final skills = _skillRegistry.all;

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: nc.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIconsRegular.arrowLeft, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Skill 管理',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: nc.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: skills.isEmpty
          ? Center(
              child: Text(
                '暂无 Skill',
                style: TextStyle(color: nc.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: skills.length,
              itemBuilder: (context, index) {
                final skill = skills[index];
                return _SkillTile(
                  skill: skill,
                  isActive: _skillRegistry.isActive(skill.id),
                  nc: nc,
                  onToggle: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (_skillRegistry.isActive(skill.id)) {
                        _skillRegistry.deactivate(skill.id);
                      } else {
                        _skillRegistry.activate(skill.id);
                      }
                    });
                  },
                  onTap: () => _showSkillDetail(skill),
                );
              },
            ),
    );
  }

  void _showSkillDetail(Skill skill) {
    final nc = AgentColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SkillDetailSheet(
        skill: skill,
        nc: nc,
        isActive: _skillRegistry.isActive(skill.id),
        onToggle: () {
          setState(() {
            if (_skillRegistry.isActive(skill.id)) {
              _skillRegistry.deactivate(skill.id);
            } else {
              _skillRegistry.activate(skill.id);
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Skill 列表项
class _SkillTile extends StatelessWidget {
  final Skill skill;
  final bool isActive;
  final AgentColors nc;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _SkillTile({
    required this.skill,
    required this.isActive,
    required this.nc,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nc.divider, width: 0.5),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? nc.primary.withValues(alpha: 0.1) : nc.primarySurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            PhosphorIconsRegular.star,
            size: 20,
            color: isActive ? nc.primary : nc.textSecondary,
          ),
        ),
        title: Text(
          skill.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: nc.textPrimary,
          ),
        ),
        subtitle: Text(
          skill.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: nc.textSecondary),
        ),
        trailing: Switch(
          value: isActive,
          onChanged: (_) => onToggle(),
          activeColor: nc.primary,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Skill 详情弹窗
class _SkillDetailSheet extends StatelessWidget {
  final Skill skill;
  final AgentColors nc;
  final bool isActive;
  final VoidCallback onToggle;

  const _SkillDetailSheet({
    required this.skill,
    required this.nc,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: nc.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: nc.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive ? nc.primary.withValues(alpha: 0.1) : nc.primarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        PhosphorIconsRegular.star,
                        size: 24,
                        color: isActive ? nc.primary : nc.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            skill.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: nc.textPrimary,
                            ),
                          ),
                          Text(
                            isActive ? '已启用' : '未启用',
                            style: TextStyle(
                              fontSize: 13,
                              color: isActive ? nc.success : nc.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '描述',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: nc.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  skill.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: nc.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (skill.keywords.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '触发关键词',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: nc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: skill.keywords.map((kw) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: nc.primarySurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          kw,
                          style: TextStyle(fontSize: 12, color: nc.textSecondary),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (skill.toolNames.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '包含工具',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: nc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: skill.toolNames.map((tool) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: nc.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tool,
                          style: TextStyle(fontSize: 12, color: nc.primary),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onToggle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive ? nc.error : nc.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(isActive ? '停用' : '启用'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
