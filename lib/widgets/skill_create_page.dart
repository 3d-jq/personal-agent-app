import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/agent_colors.dart';
import '../core/service_locator.dart';
import '../models/skill.dart';
import '../tools/skill_registry.dart';

/// Skill 创建页面
class SkillCreatePage extends StatefulWidget {
  const SkillCreatePage({super.key});

  @override
  State<SkillCreatePage> createState() => _SkillCreatePageState();
}

class _SkillCreatePageState extends State<SkillCreatePage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();
  
  int _currentStep = 0;
  final _steps = [
    '命名',
    '描述',
    '指令',
    '关键词',
    '确认',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _instructionsCtrl.dispose();
    _keywordsCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _createSkill() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写 Skill 名称')),
      );
      return;
    }

    final skill = Skill(
      id: _nameCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      instructions: _instructionsCtrl.text.trim(),
      keywords: _keywordsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );

    final registry = getIt<SkillRegistry>();
    registry.register(skill);
    registry.activate(skill.id);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Skill「${skill.name}」已创建并启用')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

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
          '创建 Skill',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: nc.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 步骤指示器
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: List.generate(_steps.length, (index) {
                final isActive = index == _currentStep;
                final isCompleted = index < _currentStep;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index < _steps.length - 1 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? nc.success
                          : isActive
                              ? nc.primary
                              : nc.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          // 步骤标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '步骤 ${_currentStep + 1}/${_steps.length}: ${_steps[_currentStep]}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: nc.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 步骤内容
          Expanded(
            child: _buildStepContent(nc),
          ),
          // 操作按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _prevStep,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: nc.textPrimary,
                        side: BorderSide(color: nc.divider),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('上一步'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _currentStep == _steps.length - 1
                        ? _createSkill
                        : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: nc.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(_currentStep == _steps.length - 1 ? '创建' : '下一步'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(AgentColors nc) {
    switch (_currentStep) {
      case 0:
        return _buildNameStep(nc);
      case 1:
        return _buildDescriptionStep(nc);
      case 2:
        return _buildInstructionsStep(nc);
      case 3:
        return _buildKeywordsStep(nc);
      case 4:
        return _buildConfirmStep(nc);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNameStep(AgentColors nc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '给你的 Skill 起个名字',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: nc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '名称应该简洁明了，能体现 Skill 的功能',
            style: TextStyle(fontSize: 14, color: nc.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            style: TextStyle(fontSize: 16, color: nc.textPrimary),
            decoration: InputDecoration(
              hintText: '例如：数据分析、内容创作、代码审查',
              hintStyle: TextStyle(color: nc.textDisabled),
              filled: true,
              fillColor: nc.primarySurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionStep(AgentColors nc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '描述 Skill 的功能',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: nc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '清晰的描述能帮助 AI 在合适的场景下自动激活这个 Skill',
            style: TextStyle(fontSize: 14, color: nc.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            style: TextStyle(fontSize: 16, color: nc.textPrimary),
            decoration: InputDecoration(
              hintText: '例如：搜索数据、整理分析、生成图表和报告',
              hintStyle: TextStyle(color: nc.textDisabled),
              filled: true,
              fillColor: nc.primarySurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsStep(AgentColors nc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '编写 Skill 指令',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: nc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '告诉 AI 在什么情况下使用这个 Skill，以及如何执行',
            style: TextStyle(fontSize: 14, color: nc.textSecondary),
          ),
          const SizedBox(height: 24),
          Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
            child: TextField(
              controller: _instructionsCtrl,
              maxLines: 8,
              style: TextStyle(fontSize: 14, color: nc.textPrimary, height: 1.6),
              decoration: InputDecoration(
                hintText: '当用户需要 XXX 时：\n1. 第一步...\n2. 第二步...\n3. 第三步...',
                hintStyle: TextStyle(color: nc.textDisabled, fontSize: 14),
                filled: true,
                fillColor: nc.primarySurface,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordsStep(AgentColors nc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '设置触发关键词',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: nc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '当用户输入包含这些关键词时，AI 会考虑激活这个 Skill',
            style: TextStyle(fontSize: 14, color: nc.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _keywordsCtrl,
            style: TextStyle(fontSize: 16, color: nc.textPrimary),
            decoration: InputDecoration(
              hintText: '用逗号分隔，例如：分析,数据,图表,报告',
              hintStyle: TextStyle(color: nc.textDisabled),
              filled: true,
              fillColor: nc.primarySurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep(AgentColors nc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '确认创建',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: nc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请确认以下信息无误',
            style: TextStyle(fontSize: 14, color: nc.textSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: nc.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: '名称', value: _nameCtrl.text, nc: nc),
                const SizedBox(height: 12),
                _InfoRow(label: '描述', value: _descCtrl.text, nc: nc),
                const SizedBox(height: 12),
                _InfoRow(
                  label: '关键词',
                  value: _keywordsCtrl.text.isEmpty ? '未设置' : _keywordsCtrl.text,
                  nc: nc,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final AgentColors nc;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.nc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label：',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: nc.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 14, color: nc.textPrimary),
          ),
        ),
      ],
    );
  }
}
