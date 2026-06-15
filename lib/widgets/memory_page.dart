import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/memory_entry.dart';
import '../services/memory_storage.dart';
import '../core/agent_colors.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});
  @override State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> with SingleTickerProviderStateMixin {
  late final _tab = TabController(length: 2, vsync: this);
  final _storage = MemoryStorage();
  List<MemoryEntry> _memories = [];
  bool _loaded = false;

  @override void initState() {
    super.initState();
    _storage.addListener(_onStorageChanged);
    _load();
    _tab.addListener(() => setState(() {}));
  }

  @override void dispose() {
    _storage.removeListener(_onStorageChanged);
    _tab.dispose();
    super.dispose();
  }

  void _onStorageChanged() {
    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    _memories = await _storage.loadAll();
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  List<MemoryEntry> get _facts => _memories.where((e) => e.type == MemoryType.fact).toList();
  List<MemoryEntry> get _prefs => _memories.where((e) => e.type == MemoryType.preference).toList();

  void _confirmDelete(MemoryEntry e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记忆'),
        content: const Text('确定要删除这条记忆吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _storage.remove(e.id);
              _load();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);
    final items = _tab.index == 0 ? _facts : _prefs;

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: nc.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text('记忆', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: nc.textPrimary)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: nc.textPrimary,
          labelColor: nc.textPrimary,
          unselectedLabelColor: nc.textSecondary,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          dividerColor: Colors.transparent,
          tabs: const [Tab(text: '我的记忆'), Tab(text: '我的喜好')],
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_border, size: 48, color: nc.textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(_tab.index == 0 ? '暂无记忆' : '暂无喜好',
                          style: TextStyle(fontSize: 15, color: nc.textSecondary.withValues(alpha: 0.6))),
                      const SizedBox(height: 6),
                      Text('在聊天中让 DWeis 帮你记住',
                          style: TextStyle(fontSize: 13, color: nc.textSecondary.withValues(alpha: 0.4))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final e = items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: nc.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 1))],
                      ),
                      child: Row(children: [
                        Expanded(child: Text(e.content, style: TextStyle(fontSize: 15, color: nc.textPrimary, height: 1.5))),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _confirmDelete(e);
                          },
                          child: Icon(Icons.close_rounded, size: 18, color: nc.textSecondary.withValues(alpha: 0.5)),
                        ),
                      ]),
                    );
                  },
                ),
    );
  }
}
