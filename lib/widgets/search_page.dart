import 'package:flutter/material.dart';
import '../core/agent_colors.dart';
import '../services/chat_storage.dart';
import '../services/note_storage.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<_SearchResult> _results = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final q = query.toLowerCase();
    final results = <_SearchResult>[];

    final sessions = await ChatStorage().loadAll();
    for (final s in sessions) {
      if (s.title.toLowerCase().contains(q)) {
        results.add(_SearchResult(type: '对话', title: s.title, subtitle: '${s.messages.length} 条消息', icon: Icons.chat_bubble_outline));
      }
    }

    final notes = await NoteStorage().loadAll();
    for (final n in notes) {
      if (n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q)) {
        results.add(_SearchResult(type: '笔记', title: n.title, subtitle: n.summary, icon: Icons.note_outlined));
      }
    }

    setState(() {
      _results = results;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nc = AgentColors.of(context);

    return Scaffold(
      backgroundColor: nc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          style: TextStyle(fontSize: 16, color: nc.textPrimary),
          decoration: InputDecoration(
            hintText: '搜索对话、笔记...',
            hintStyle: TextStyle(color: nc.textSecondary.withValues(alpha: 0.5)),
            border: InputBorder.none,
          ),
          onChanged: _search,
        ),
      ),
      body: _ctrl.text.isEmpty
          ? Center(
              child: Text('输入关键词搜索',
                  style: TextStyle(fontSize: 14, color: nc.textSecondary.withValues(alpha: 0.5))),
            )
          : _results.isEmpty
              ? Center(
                  child: Text(_loaded ? '没有找到相关内容' : '搜索中...',
                      style: TextStyle(fontSize: 14, color: nc.textSecondary.withValues(alpha: 0.5))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(context, r),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: nc.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: nc.primarySurface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(r.icon, size: 18, color: nc.textPrimary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: nc.primarySurface,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(r.type, style: TextStyle(fontSize: 10, color: nc.textSecondary)),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: nc.textPrimary)),
                                      ),
                                    ]),
                                    if (r.subtitle.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(r.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: nc.textSecondary)),
                                    ],
                                  ],
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _SearchResult {
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  const _SearchResult({required this.type, required this.title, required this.subtitle, required this.icon});
}
