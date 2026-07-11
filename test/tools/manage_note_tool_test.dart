import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/models/note.dart';
import 'package:personal_agent_app/services/note_storage.dart';
import 'package:personal_agent_app/tools/manage_note_tool.dart';

/// 内存版笔记存储，避免测试触碰真实 SQLite。只覆盖工具用到的方法。
class _FakeNoteStorage extends NoteStorage {
  final List<Note> _notes;
  _FakeNoteStorage(this._notes);

  @override
  Future<List<Note>> loadAll() async => List<Note>.from(_notes);

  @override
  Future<void> update(Note note) async {
    final idx = _notes.indexWhere((n) => n.id == note.id);
    if (idx >= 0) _notes[idx] = note;
  }

  @override
  Future<void> remove(String id) async {
    _notes.removeWhere((n) => n.id == id);
  }
}

void main() {
  late _FakeNoteStorage fake;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await resetDependencies();
    await configureDependencies();
    fake = _FakeNoteStorage([
      Note(
        id: '1',
        title: '购物清单',
        content: '# 超市\n- 牛奶\n- 鸡蛋',
        createdAt: DateTime(2026, 1, 1),
      ),
      Note(
        id: '2',
        title: '读书笔记',
        content: '《xxx》核心观点：少即是多。',
        createdAt: DateTime(2026, 2, 2),
      ),
    ]);
    getIt.unregister<NoteStorage>();
    getIt.registerSingleton<NoteStorage>(fake);
  });

  tearDown(() async {
    await resetDependencies();
  });

  group('NotesReadTool', () {
    test('read 返回指定笔记的完整正文（含标题与 Markdown 内容）', () async {
      final tool = NotesReadTool();
      final out = await tool.execute({'note_id': '1'});
      expect(out, contains('购物清单'));
      expect(out, contains('id: 1'));
      expect(out, contains('# 超市'));
      expect(out, contains('- 牛奶'));
    });

    test('read 找不到 id 时自动回退到 list 并给出提示', () async {
      final tool = NotesReadTool();
      final out = await tool.execute({'note_id': '999'});
      expect(out, contains('找不到 id 为 "999" 的笔记'));
      expect(out, contains('购物清单')); // 列表里能看到可用 id
    });

    test('read 未提供 note_id 时给出提示', () async {
      final tool = NotesReadTool();
      final out = await tool.execute({});
      expect(out, contains('未提供 note_id'));
    });
  });
}
