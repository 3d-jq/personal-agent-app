import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import '../core/agent_colors.dart';
import '../services/ai_service.dart';
import '../services/crypto_util.dart';

// ── Vendor ──

class VendorConfig {
  final String id;
  String name, apiKey, baseUrl, model;
  bool isBuiltIn;
  VendorConfig({required this.id, required this.name, required this.apiKey, required this.baseUrl, this.model = '', this.isBuiltIn = false});
  Map<String, dynamic> toJson() => {'id':id,'name':name,'apiKey':apiKey,'baseUrl':baseUrl,'model':model,'isBuiltIn':isBuiltIn};
  factory VendorConfig.fromJson(Map<String, dynamic> j) => VendorConfig(id:j['id'] as String, name:j['name'] as String, apiKey:j['apiKey'] as String? ?? '', baseUrl:j['baseUrl'] as String? ?? '', model:j['model'] as String? ?? '', isBuiltIn:j['isBuiltIn'] as bool? ?? false);
  VendorConfig copyWith({String? name, String? apiKey, String? baseUrl, String? model}) => VendorConfig(id:id, name:name??this.name, apiKey:apiKey??this.apiKey, baseUrl:baseUrl??this.baseUrl, model:model??this.model, isBuiltIn:isBuiltIn);
}

// ── Settings ──

class AISettings {
  AISettings();

  static List<(String, String, String)> _builtIn = [];
  List<VendorConfig> vendors = [];
  String? selectedVendorId;
  bool _loaded = false;

  /// 思考强度: low / medium / high，默认 medium
  String thinkingEffort = 'medium';

  VendorConfig? get selectedVendor => vendors.where((v) => v.id == selectedVendorId).firstOrNull;
  String get apiKey => selectedVendor?.apiKey ?? '';
  String get baseUrl => selectedVendor?.baseUrl ?? '';
  String get effectiveModel => selectedVendor?.model ?? '';
  bool get hasVendor => selectedVendor != null && selectedVendor!.apiKey.isNotEmpty;

  void _ensureBuiltIn() {
    final agnesKey = CryptoUtil.decrypt(dotenv.env['AGNES_API_KEY'] ?? '');
    _builtIn = [
      ('Agnes-2.0-Flash', agnesKey, 'https://apihub.agnes-ai.com/v1'),
    ];
    for (final b in _builtIn) {
      if (!vendors.any((v) => v.name == b.$1)) {
        vendors.add(VendorConfig(id: b.$1, name: b.$1, apiKey: b.$2, baseUrl: b.$3, isBuiltIn: true));
      }
    }
  }

  void selectVendor(String id) { selectedVendorId = id; save(); final v = vendors.where((x) => x.id == id).firstOrNull; if (v != null && v.model.isEmpty) { v.model = id == 'Agnes-2.0-Flash' ? 'agnes-2.0-flash' : 'deepseek-chat'; save(); } }
  void setVendorModel(String vid, String m) { final v = vendors.where((x) => x.id == vid).firstOrNull; if (v != null) { v.model = m; save(); } }
  void addVendor(VendorConfig v) { vendors.add(v); selectedVendorId = v.id; save(); }
  void updateVendor(VendorConfig v) { final i = vendors.indexWhere((x) => x.id == v.id); if (i >= 0) vendors[i] = v; save(); }
  void removeVendor(String id) { vendors.removeWhere((x) => x.id == id); if (selectedVendorId == id) selectedVendorId = vendors.isNotEmpty ? vendors.first.id : null; save(); }

  Future<File> _file() async { final d = await getApplicationDocumentsDirectory(); return File('${d.path}/ai_settings.json'); }
  Future<void> load() async { if (_loaded) return; try { final f = await _file(); if (await f.exists()) { final d = jsonDecode(await f.readAsString()) as Map<String, dynamic>; selectedVendorId = d['vendor'] as String?; vendors = (d['vendors'] as List?)?.map((x) => VendorConfig.fromJson(x as Map<String, dynamic>)).toList() ?? []; thinkingEffort = d['thinkingEffort'] as String? ?? 'medium'; } } catch (_) {} _ensureBuiltIn(); if (selectedVendorId == null && vendors.isNotEmpty) { selectVendor(vendors.first.id); } _loaded = true; }
  Future<void> save() async { await _file().then((f) => f.writeAsString(jsonEncode({'vendor':selectedVendorId, 'vendors':vendors.map((v) => v.toJson()).toList(), 'thinkingEffort':thinkingEffort}))); }
}

// ── Backend picker ──

void showBackendPicker(BuildContext context, AISettings s, VoidCallback cb) {
  final nc = AgentColors.of(context);
  showModalBottomSheet(context:context, shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(20))), builder:(ctx)=>Padding(padding:const EdgeInsets.only(bottom:32), child:Column(mainAxisSize:MainAxisSize.min, children:[
    Container(margin:const EdgeInsets.only(top:8), width:36, height:4, decoration:BoxDecoration(color:nc.divider, borderRadius:BorderRadius.circular(2))),
    Padding(padding:const EdgeInsets.symmetric(vertical:16), child:Text('选择 AI 厂商', style:TextStyle(fontSize:16, fontWeight:FontWeight.w600, color:nc.textPrimary))),
    ...s.vendors.map((v)=>_VendorTile(vendor:v, isSelected:s.selectedVendorId==v.id, onSelect:(){ s.selectVendor(v.id); cb(); Navigator.pop(ctx); }, onEdit:(){ Navigator.pop(ctx); _showEditVendor(context,s,v,cb); }, onDelete:()async{ Navigator.pop(ctx); final ok=await showDialog<bool>(context:context, builder:(c)=>AlertDialog(title:const Text('删除厂商'), content:Text('确定要删除「${v.name}」吗？'), actions:[TextButton(onPressed:()=>Navigator.pop(c,false), child:const Text('取消')), TextButton(onPressed:()=>Navigator.pop(c,true), child:const Text('删除'))])); if(ok==true){ s.removeVendor(v.id); cb(); } })),
    const SizedBox(height:8),
    _AddVendorTile(onTap:(){
      HapticFeedback.lightImpact();
      Navigator.pop(ctx); _showAddVendor(context,s,cb);
    }),
  ])));
}

void _showAddVendor(BuildContext context, AISettings s, VoidCallback cb) {
  final nCtrl=TextEditingController(), kCtrl=TextEditingController(), uCtrl=TextEditingController();
  showModalBottomSheet(context:context, isScrollControlled:true, shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(20))), builder:(ctx)=>_AddVendorBody(nameCtrl:nCtrl, keyCtrl:kCtrl, urlCtrl:uCtrl, settings:s, onChanged:cb));
}

class _AddVendorBody extends StatefulWidget {
  final TextEditingController nameCtrl, keyCtrl, urlCtrl; final AISettings settings; final VoidCallback onChanged;
  const _AddVendorBody({required this.nameCtrl, required this.keyCtrl, required this.urlCtrl, required this.settings, required this.onChanged});
  @override State<_AddVendorBody> createState() => _AddVendorBodyState();
}

class _AddVendorBodyState extends State<_AddVendorBody> {
  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return Padding(padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('添加 API 厂商', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), const SizedBox(height: 16),
      TextField(controller: widget.nameCtrl, decoration: const InputDecoration(labelText: '厂商名称', hintText: '例如: DeepSeek, OpenAI', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))))),
      const SizedBox(height: 12),
      TextField(controller: widget.keyCtrl, decoration: const InputDecoration(labelText: 'API Key', hintText: 'sk-...', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))))),
      const SizedBox(height: 12),
      TextField(controller: widget.urlCtrl, decoration: const InputDecoration(labelText: 'Base URL（可选）', hintText: 'https://api.openai.com/v1', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))))),
      const SizedBox(height: 24),
      FilledButton(onPressed: () { final n = widget.nameCtrl.text.trim(), k = widget.keyCtrl.text.trim(); if (n.isEmpty || k.isEmpty) return; final u = widget.urlCtrl.text.trim().isNotEmpty ? widget.urlCtrl.text.trim() : 'https://api.deepseek.com/v1'; widget.settings.addVendor(VendorConfig(id: DateTime.now().millisecondsSinceEpoch.toString(), name: n, apiKey: k, baseUrl: u, model: 'deepseek-chat')); widget.onChanged(); Navigator.of(context).pop(); }, child: const Text('添加')),
    ])));
  }
}

void _showEditVendor(BuildContext context, AISettings s, VendorConfig v, VoidCallback cb) {
  final nCtrl=TextEditingController(text:v.name), kCtrl=TextEditingController(text:v.apiKey), uCtrl=TextEditingController(text:v.baseUrl);
  showModalBottomSheet(context:context, isScrollControlled:true, shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(20))), builder:(ctx)=>_EditVendorBody(vendor:v, nameCtrl:nCtrl, keyCtrl:kCtrl, urlCtrl:uCtrl, settings:s, onChanged:cb));
}

class _EditVendorBody extends StatefulWidget {
  final VendorConfig vendor; final TextEditingController nameCtrl, keyCtrl, urlCtrl; final AISettings settings; final VoidCallback onChanged;
  const _EditVendorBody({required this.vendor, required this.nameCtrl, required this.keyCtrl, required this.urlCtrl, required this.settings, required this.onChanged});
  @override State<_EditVendorBody> createState() => _EditVendorBodyState();
}

class _EditVendorBodyState extends State<_EditVendorBody> {
  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final isBuiltIn = widget.vendor.isBuiltIn;
    return Padding(padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(isBuiltIn ? '配置 Agnes' : '编辑 API 厂商', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: nc.textPrimary)), const SizedBox(height: 16),
      if (isBuiltIn)
        Text('Agnes 是内置 AI 服务，提供图片和视频生成能力。', style: TextStyle(fontSize: 13, color: nc.textSecondary)),
      const SizedBox(height: 12),
      if (!isBuiltIn) ...[
        TextField(controller: widget.nameCtrl, decoration: InputDecoration(labelText: '厂商名称', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))), labelStyle: TextStyle(color: nc.textSecondary))),
        const SizedBox(height: 12),
        TextField(controller: widget.urlCtrl, decoration: InputDecoration(labelText: 'Base URL（可选）', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))), labelStyle: TextStyle(color: nc.textSecondary))),
        const SizedBox(height: 12),
      ],
      TextField(controller: widget.keyCtrl, decoration: InputDecoration(labelText: isBuiltIn ? 'Agnes API Key' : 'API Key', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))), labelStyle: TextStyle(color: nc.textSecondary))),
      const SizedBox(height: 24),
      FilledButton(onPressed: () { final k = widget.keyCtrl.text.trim(); if (k.isEmpty) return; final n = isBuiltIn ? widget.vendor.name : widget.nameCtrl.text.trim(); final u = isBuiltIn ? widget.vendor.baseUrl : (widget.urlCtrl.text.trim().isNotEmpty ? widget.urlCtrl.text.trim() : widget.vendor.baseUrl); widget.settings.updateVendor(widget.vendor.copyWith(name: n, apiKey: k, baseUrl: u)); widget.onChanged(); Navigator.of(context).pop(); }, child: const Text('保存')),
    ])));
  }
}

// ── Model picker ──

void showModelPicker(BuildContext context, AISettings s, VoidCallback cb) {
  final v = s.selectedVendor; if (v == null) return;
  showModalBottomSheet(context:context, isScrollControlled:true, shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(20))), builder:(_)=>_ModelPickBody(vendor:v, settings:s, onChanged:cb));
}

class _ModelPickBody extends StatefulWidget {
  final VendorConfig vendor; final AISettings settings; final VoidCallback onChanged;
  const _ModelPickBody({required this.vendor, required this.settings, required this.onChanged});
  @override State<_ModelPickBody> createState() => _ModelPickBodyState();
}

class _ModelPickBodyState extends State<_ModelPickBody> {
  List<String>? _fetched; bool _loading = false; String? _error;
  @override void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; _fetched = null; });
    try {
      final m = await AIService(baseUrl: widget.vendor.baseUrl, apiKey: widget.vendor.apiKey, providerName: widget.vendor.name, model: '').fetchModels();
      if (mounted) setState(() { _fetched = m; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  List<String> get _models => _fetched ?? [];
  String get _current => widget.vendor.model.isNotEmpty ? widget.vendor.model : 'deepseek-chat';

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final maxH = MediaQuery.of(context).size.height * 0.55;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 8), width: 36, height: 4, decoration: BoxDecoration(color: nc.divider, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [
          Expanded(child: Text('选择模型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: nc.textPrimary))),
          if (_loading)
              Padding(padding: const EdgeInsets.only(right: 4), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(nc.textPrimary)))),
            if (!_loading)
              GestureDetector(onTap: _fetch, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.refresh_rounded, size: 18, color: nc.textSecondary))),
        ])),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_error!, style: TextStyle(fontSize: 12, color: nc.error))),
        Flexible(child: ListView(children: [
          ..._models.map((m) { final sel = m == _current; return ListTile(title: Text(m, style: TextStyle(fontSize: 14, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? nc.success : nc.textPrimary)), trailing: sel ? Icon(Icons.check_circle, size: 20, color: nc.success) : null, onTap: () { HapticFeedback.lightImpact(); widget.settings.setVendorModel(widget.vendor.id, m); widget.onChanged(); Navigator.pop(context); }); }),
        ])),
      ]),
    );
  }
}

// ── Widgets ──

class _VendorTile extends StatelessWidget {
  final VendorConfig vendor; final bool isSelected; final VoidCallback onSelect, onEdit, onDelete;
  const _VendorTile({required this.vendor, required this.isSelected, required this.onSelect, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return ListTile(
      leading: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? nc.success : nc.textSecondary, size: 22),
      title: Row(children: [
        Flexible(child: Text(vendor.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: nc.textPrimary))),
        if (vendor.isBuiltIn) ...[
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: nc.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)), child: Text('内置', style: TextStyle(fontSize: 10, color: nc.success, fontWeight: FontWeight.w600))),
        ],
      ]),
      subtitle: Text(vendor.model.isNotEmpty ? vendor.model : '未设置模型', style: TextStyle(fontSize: 12, color: nc.textSecondary)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: nc.textSecondary), onPressed: () { HapticFeedback.lightImpact(); onEdit(); }),
        if (!vendor.isBuiltIn)
          IconButton(icon: Icon(Icons.delete_outline, size: 18, color: nc.error), onPressed: () { HapticFeedback.lightImpact(); onDelete(); }),
      ]),
      onTap: () { HapticFeedback.lightImpact(); onSelect(); },
    );
  }
}

class _AddVendorTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddVendorTile({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    return ListTile(leading: Icon(Icons.add_circle_outline, color: nc.textSecondary, size: 22), title: Text('添加厂商', style: TextStyle(fontSize: 15, color: nc.textSecondary)), onTap: onTap);
  }
}
