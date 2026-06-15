import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/note_storage.dart';
import 'base_tool.dart';

class SaveNoteTool extends AgentTool {
  @override
  String get name => 'save_note';

  @override
  String get description => '将内容保存为笔记。当用户要求记录、总结、保存、记下某些内容时调用此工具。如果用户要求图文并茂的笔记，先调用 generate_image 生成图片，再将图片路径通过 images 参数传入。严禁在未真正调用本工具的情况下对用户声称"已保存/已记录/已为你记下笔记"——必须先调用本工具并看到成功返回，才能告知用户已完成。';

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
      id: const Uuid().v4(),
      title: title,
      content: content,
    );

    await NoteStorage().add(note);
    return '笔记已保存：「$title」${images.isNotEmpty ? '（含 ${images.length} 张图片）' : ''}';
  }
}
