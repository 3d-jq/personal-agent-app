import '../models/note.dart';
import '../services/note_storage.dart';
import 'base_tool.dart';
import 'save_note_tool.g.dart';

class SaveNoteTool extends AgentTool {
  @override String get name => 'save_note';
  @override bool get readOnly => false;

  @override
  String get description => saveNoteToolDescription;

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': '笔记标题，简洁概括内容主题',
          },
          'content': {
            'type': 'string',
            'description': '笔记正文内容，支持 Markdown 格式',
          },
          'images': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '图片文件路径列表（file:// 格式），来自 generate_image 工具的返回结果。按顺序插入到内容对应位置',
          },
        },
        'required': ['title', 'content'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final title = args['title'] as String? ?? '无标题笔记';
    var content = args['content'] as String? ?? '';
    final images = (args['images'] as List?)?.cast<String>() ?? [];

    if (images.isNotEmpty) {
      final buf = StringBuffer(content);
      for (final img in images) {
        final path = img.startsWith('file://') ? img : 'file://$img';
        buf.writeln('\n\n![配图]($path)');
      }
      content = buf.toString();
    }

    final note = Note(
      id: await NoteStorage().nextId(),
      title: title,
      content: content,
    );

    await NoteStorage().add(note);
    return '笔记已保存：「$title」${images.isNotEmpty ? '（含 ${images.length} 张图片）' : ''}';
  }
}
