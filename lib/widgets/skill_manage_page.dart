import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../core/design_tokens.dart';
import '../core/service_locator.dart';
import '../models/skill.dart';
import 'common_widgets.dart';
import '../tools/skill_registry.dart';

/// Skill 管理页面
class SkillManagePage extends StatelessWidget {
  const SkillManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final skills = getIt<SkillRegistry>().all;

    return Scaffold(
      backgroundColor: nc.background,
      body: skills.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    size: 48,
                    color: nc.textSecondary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无 Skill',
                    style: TextStyle(color: nc.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '在对话中告诉 AI"帮我创建一个 Skill"即可',
                    style: TextStyle(fontSize: 12, color: nc.textDisabled),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: skills.length,
              itemBuilder: (context, index) {
                final skill = skills[index];
                return _SkillTile(
                  skill: skill,
                  nc: nc,
                      onTap: () => _showSkillDetail(context, skill),
                );
              },
            ),
    );
  }

  void _showSkillDetail(BuildContext context, Skill skill) {
    final nc = AgentColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SkillDetailSheet(
        skill: skill,
        nc: nc,
      ),
    );
  }
}

/// Skill 列表项
class _SkillTile extends StatelessWidget {
  final Skill skill;
  final AgentColors nc;
  final VoidCallback onTap;

  const _SkillTile({
    required this.skill,
    required this.nc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final leadingIcon = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: nc.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(RadiusToken.sm),
      ),
      child: Icon(
        Icons.star,
        size: 20,
        color: nc.primary,
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: SpaceToken.sm),
      child: ElevatedCard(
        nc: nc,
        child: Theme(
          data: Theme.of(context).copyWith(splashFactory: NoSplash.splashFactory),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: SpaceToken.lg,
              vertical: SpaceToken.sm,
            ),
            leading: leadingIcon,
            title: Text(
              skill.name,
              style: TextStyle(
                fontSize: FontToken.body,
                fontWeight: WeightToken.medium,
                color: nc.textPrimary,
              ),
            ),
            subtitle: Text(
              skill.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: FontToken.small, color: nc.textSecondary),
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

/// Skill 详情弹窗
class _SkillDetailSheet extends StatelessWidget {
  final Skill skill;
  final AgentColors nc;

  const _SkillDetailSheet({
    required this.skill,
    required this.nc,
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
        borderRadius: BorderRadius.circular(RadiusToken.xl),
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
                        color: nc.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(RadiusToken.md),
                      ),
                      child: Icon(
                        Icons.star,
                        size: 24,
                        color: nc.primary,
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
                            '已启用',
                            style: TextStyle(
                              fontSize: 13,
                              color: nc.success,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: nc.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  skill.description,
                  style: TextStyle(
                    fontSize: 15,
                    color: nc.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (skill.keywords.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '触发关键词',
                    style: TextStyle(
                      fontSize: 15,
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
                          borderRadius: BorderRadius.circular(RadiusToken.sm),
                        ),
                        child: Text(
                          kw,
                          style: TextStyle(fontSize: 12, color: nc.textSecondary),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
