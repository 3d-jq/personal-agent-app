import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/agent_colors.dart';
import '../core/service_locator.dart';
import '../widgets/ai_settings_sheet.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingPage({super.key, required this.onComplete});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _nameCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String _selectedPreset = 'DeepSeek';
  int _step = 0;

  final _presets = [
    ('DeepSeek', 'https://api.deepseek.com/v1', 'deepseek-chat'),
    ('OpenAI', 'https://api.openai.com/v1', 'gpt-4o'),
    ('Agnes', 'https://apihub.agnes-ai.com/v1', 'agnes-2.0-flash'),
  ];

  @override
  void initState() {
    super.initState();
    _applyPreset('DeepSeek');
  }

  void _applyPreset(String name) {
    final p = _presets.firstWhere((e) => e.$1 == name);
    _selectedPreset = name;
    _nameCtrl.text = p.$1;
    _urlCtrl.text = p.$2;
    _keyCtrl.clear();
    setState(() {});
  }

  void _complete() {
    final k = _keyCtrl.text.trim();
    if (k.isEmpty) return;
    final settings = getIt<AISettings>();
    final preset = _presets.firstWhere((e) => e.$1 == _selectedPreset);
    settings.addVendor(
      VendorConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: preset.$1,
        apiKey: k,
        baseUrl: _urlCtrl.text.trim().isNotEmpty
            ? _urlCtrl.text.trim()
            : preset.$2,
        model: preset.$3,
      ),
    );
    settings.selectVendor(settings.vendors.last.id);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: nc.background,
      body: SafeArea(
        child: _step == 0 ? _buildWelcome(nc, size) : _buildConfig(nc),
      ),
    );
  }

  Widget _buildWelcome(AgentColors nc, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: nc.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.smart_toy_outlined, size: 44, color: nc.success),
          ),
          const SizedBox(height: 24),
          Text(
            '欢迎使用 DWeis',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: nc.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '你的全能 AI 助手\n可以聊天、搜索、生成图片视频、管理笔记和提醒',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: nc.textSecondary,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 3),
          FilledButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _step = 1);
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: nc.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '开始设置',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.onComplete();
            },
            child: Text(
              '稍后设置',
              style: TextStyle(fontSize: 14, color: nc.textSecondary),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildConfig(AgentColors nc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => setState(() => _step = 0),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: nc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '配置 AI 后端',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: nc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '选择一个服务商并填入 API Key',
            style: TextStyle(fontSize: 14, color: nc.textSecondary),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((p) {
              final sel = _selectedPreset == p.$1;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _applyPreset(p.$1);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? nc.success.withValues(alpha: 0.12)
                        : nc.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? nc.success : nc.divider,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    p.$1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      color: sel ? nc.success : nc.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _keyCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'API Key *',
              hintText: 'sk-...',
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              labelStyle: TextStyle(color: nc.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtrl,
            decoration: InputDecoration(
              labelText: 'Base URL',
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              labelStyle: TextStyle(color: nc.textSecondary),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _keyCtrl.text.trim().isEmpty ? null : _complete,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: nc.success,
              disabledBackgroundColor: nc.divider,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '完成设置',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }
}
