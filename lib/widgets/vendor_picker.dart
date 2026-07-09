import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/agent_colors.dart';
import 'ai_settings.dart';
import 'vendor_config.dart';

void showBackendPicker(BuildContext context, AISettings s, VoidCallback cb) {
  final nc = AgentColors.of(context);
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
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
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              '选择 AI 厂商',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: nc.textPrimary,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              shrinkWrap: true,
              children: [
                ...s.vendors.map(
                  (v) => _VendorTile(
                    vendor: v,
                    isSelected: s.selectedVendorId == v.id,
                    onSelect: () {
                      s.selectVendor(v.id);
                      cb();
                      Navigator.pop(ctx);
                    },
                    onEdit: () {
                      Navigator.pop(ctx);
                      _showEditVendor(context, s, v, cb);
                    },
                    onDelete: () async {
                      Navigator.pop(ctx);
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('删除厂商'),
                          content: Text('确定要删除「${v.name}」吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        s.removeVendor(v.id);
                        cb();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          _AddVendorTile(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx);
              _showAddVendor(context, s, cb);
            },
          ),
        ],
      ),
    ),
  );
}

void _showAddVendor(BuildContext context, AISettings s, VoidCallback cb) {
  final nCtrl = TextEditingController(),
      kCtrl = TextEditingController(),
      uCtrl = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _AddVendorBody(
      nameCtrl: nCtrl,
      keyCtrl: kCtrl,
      urlCtrl: uCtrl,
      settings: s,
      onChanged: cb,
    ),
  );
}

class _AddVendorBody extends StatefulWidget {
  final TextEditingController nameCtrl, keyCtrl, urlCtrl;
  final AISettings settings;
  final VoidCallback onChanged;
  const _AddVendorBody({
    required this.nameCtrl,
    required this.keyCtrl,
    required this.urlCtrl,
    required this.settings,
    required this.onChanged,
  });
  @override
  State<_AddVendorBody> createState() => _AddVendorBodyState();
}

class _AddVendorBodyState extends State<_AddVendorBody> {
  String _protocol = 'openai';
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '添加 API 厂商',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.nameCtrl,
              decoration: const InputDecoration(
                labelText: '厂商名称',
                hintText: '例如: DeepSeek, OpenAI',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.keyCtrl,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Base URL（可选）',
                hintText: 'https://api.openai.com/v1',
              ),
            ),
            const SizedBox(height: 12),
            _ProtocolSelector(
              value: _protocol,
              onChanged: (p) => setState(() => _protocol = p),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final n = widget.nameCtrl.text.trim(),
                    k = widget.keyCtrl.text.trim();
                if (n.isEmpty || k.isEmpty) return;
                final u = widget.urlCtrl.text.trim().isNotEmpty
                    ? widget.urlCtrl.text.trim()
                    : 'https://api.deepseek.com/v1';
                widget.settings.addVendor(
                  VendorConfig(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: n,
                    apiKey: k,
                    baseUrl: u,
                    model: 'deepseek-chat',
                    protocol: _protocol,
                  ),
                );
                widget.onChanged();
                Navigator.of(context).pop();
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}

void _showEditVendor(
  BuildContext context,
  AISettings s,
  VendorConfig v,
  VoidCallback cb,
) {
  final nCtrl = TextEditingController(text: v.name),
      kCtrl = TextEditingController(text: v.apiKey),
      uCtrl = TextEditingController(text: v.baseUrl);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _EditVendorBody(
      vendor: v,
      nameCtrl: nCtrl,
      keyCtrl: kCtrl,
      urlCtrl: uCtrl,
      settings: s,
      onChanged: cb,
    ),
  );
}

class _EditVendorBody extends StatefulWidget {
  final VendorConfig vendor;
  final TextEditingController nameCtrl, keyCtrl, urlCtrl;
  final AISettings settings;
  final VoidCallback onChanged;
  const _EditVendorBody({
    required this.vendor,
    required this.nameCtrl,
    required this.keyCtrl,
    required this.urlCtrl,
    required this.settings,
    required this.onChanged,
  });
  @override
  State<_EditVendorBody> createState() => _EditVendorBodyState();
}

class _EditVendorBodyState extends State<_EditVendorBody> {
  String _protocol = 'openai';
  @override
  void initState() {
    super.initState();
    _protocol = widget.vendor.protocol;
  }
  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final isBuiltIn = widget.vendor.isBuiltIn;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isBuiltIn ? '配置 Agnes' : '编辑 API 厂商',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: nc.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (isBuiltIn)
              Text(
                'Agnes 是内置 AI 服务，提供图片和视频生成能力。',
                style: TextStyle(fontSize: 13, color: nc.textSecondary),
              ),
            const SizedBox(height: 12),
            if (!isBuiltIn) ...[
              TextField(
                controller: widget.nameCtrl,
                decoration: InputDecoration(
                  labelText: '厂商名称',
                  labelStyle: TextStyle(color: nc.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: widget.urlCtrl,
                decoration: InputDecoration(
                  labelText: 'Base URL（可选）',
                  labelStyle: TextStyle(color: nc.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              _ProtocolSelector(
                value: _protocol,
                onChanged: (p) => setState(() => _protocol = p),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: widget.keyCtrl,
              decoration: InputDecoration(
                labelText: isBuiltIn ? 'Agnes API Key' : 'API Key',
                labelStyle: TextStyle(color: nc.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final k = widget.keyCtrl.text.trim();
                if (k.isEmpty) return;
                final n = isBuiltIn
                    ? widget.vendor.name
                    : widget.nameCtrl.text.trim();
                final u = isBuiltIn
                    ? widget.vendor.baseUrl
                    : (widget.urlCtrl.text.trim().isNotEmpty
                          ? widget.urlCtrl.text.trim()
                          : widget.vendor.baseUrl);
                widget.settings.updateVendor(
                  widget.vendor.copyWith(
                    name: n,
                    apiKey: k,
                    baseUrl: u,
                    protocol: _protocol,
                  ),
                );
                widget.onChanged();
                Navigator.of(context).pop();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorTile extends StatelessWidget {
  final VendorConfig vendor;
  final bool isSelected;
  final VoidCallback onSelect, onEdit, onDelete;
  const _VendorTile({
    required this.vendor,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle_outline : Icons.circle_outlined,
        color: isSelected ? nc.success : nc.textSecondary,
        size: 22,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              vendor.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: nc.textPrimary,
              ),
            ),
          ),
          if (vendor.isBuiltIn) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: nc.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '内置',
                style: TextStyle(
                  fontSize: 10,
                  color: nc.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        vendor.isBuiltIn
            ? (vendor.model.isNotEmpty ? vendor.model : '未设置模型')
            : '${vendor.model.isNotEmpty ? vendor.model : '未设置模型'} · ${vendor.protocol == 'anthropic' ? 'Anthropic 格式' : 'OpenAI 格式'}',
        style: TextStyle(fontSize: 12, color: nc.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit, size: 18, color: nc.textSecondary),
            onPressed: () {
              HapticFeedback.lightImpact();
              onEdit();
            },
          ),
          if (!vendor.isBuiltIn)
            IconButton(
              icon: Icon(Icons.delete, size: 18, color: nc.error),
              onPressed: () {
                HapticFeedback.lightImpact();
                onDelete();
              },
            ),
        ],
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onSelect();
      },
    );
  }
}

class _AddVendorTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddVendorTile({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return ListTile(
      leading: Icon(
        Icons.add_circle_outline,
        color: nc.textSecondary,
        size: 22,
      ),
      title: Text(
        '添加厂商',
        style: TextStyle(fontSize: 15, color: nc.textSecondary),
      ),
      onTap: onTap,
    );
  }
}

/// OpenAI / Anthropic 接口协议分段选择器（Apple HIG 风格）
class _ProtocolSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ProtocolSelector({
    required this.value,
    required this.onChanged,
  });

  static const _options = [
    (value: 'openai', label: 'OpenAI 格式'),
    (value: 'anthropic', label: 'Anthropic 格式'),
  ];

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '接口协议',
          style: TextStyle(fontSize: 13, color: nc.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < _options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(_options[i].value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == _options[i].value
                          ? nc.primary.withValues(alpha: 0.12)
                          : nc.fillTertiary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: value == _options[i].value
                            ? nc.primary
                            : nc.divider,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _options[i].label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: value == _options[i].value
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: value == _options[i].value
                            ? nc.primary
                            : nc.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}