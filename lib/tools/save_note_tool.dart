import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/note_storage.dart';
import 'base_tool.dart';

class SaveNoteTool extends AgentTool {
  @override
  String get name => 'save_note';

  @override
  String get description => '将内容保存为笔记。当用户要求记录、总结、保存、记下某些内容时调用此工具。';

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
        },
        'required': ['title', 'content'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final title = args['title'] as String? ?? '无标题笔记';
    final content = args['content'] as String? ?? '';

    final note = Note(
      id: const Uuid().v4(),
      title: title,
      content: content,
    );

    await NoteStorage().add(note);
    return '笔记已保存：「$title」';
  }
}
