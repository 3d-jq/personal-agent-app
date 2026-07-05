import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/agent_colors.dart';

class AcknowledgementView extends StatelessWidget {
  const AcknowledgementView({super.key});

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIconsRegular.arrowLeft, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '致谢',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: nc.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sapiens AI / Agnes AI ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: nc.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: nc.divider, width: 0.5),
              ),
              child: Column(
                children: [
                  Text(
                    'Agnes AI',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: nc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by Sapiens AI',
                    style: TextStyle(fontSize: 14, color: nc.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Sapiens AI 是 Agnes AI 的母公司，专注于研发先进的多模态 AI 模型与基础设施，致力于为下一代智能应用、创意应用和交互式产品提供强大的 AI 能力支持。',
                    style: TextStyle(
                      fontSize: 15,
                      color: nc.textPrimary,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: nc.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '让世界级 AI 属于每一个人。',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: nc.textPrimary,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '通过 Agnes AI，我们希望降低高质量 AI 技术的使用门槛，让开发者、创作者、创业团队和企业都能够以更简单、更稳定、更低成本的方式，将先进的 AI 能力接入自己的产品与业务中。',
                          style: TextStyle(
                            fontSize: 14,
                            color: nc.textSecondary,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '我们相信，世界级 AI 不应该只属于少数大型机构，而应该成为每一位开发者都能使用、每一个产品都能集成、每一个用户都能受益的基础能力。',
                          style: TextStyle(
                            fontSize: 14,
                            color: nc.textSecondary,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agnes AI，让世界级 AI 属于每一个人。',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: nc.textPrimary,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ── Thanks note ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: nc.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: nc.divider),
              ),
              child: Column(
                children: [
                  Icon(
                    PhosphorIconsRegular.heart,
                    size: 28,
                    color: nc.error.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '本项目中的图片生成和视频生成功能，均由 Agnes AI 免费开放的大模型提供支持。',
                    style: TextStyle(
                      fontSize: 15,
                      color: nc.textPrimary,
                      height: 1.7,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '感谢 Sapiens AI 让世界级 AI 对每一个人开放。',
                    style: TextStyle(fontSize: 14, color: nc.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
