import '../models/note.dart';
import '../services/crypto_util.dart';
import '../services/note_storage.dart';
import 'agnes_image_tool.dart';
import 'base_tool.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 一步生成图文笔记：内部自动生图 → 拼接 Markdown → 保存。
///
/// 避免 AI 先调 generate_image 再调 save_note 的两步断裂问题。
class CreateRichNoteTool extends AgentTool {
  @override
  String get name => 'create_rich_note';

  @override
  bool get readOnly => false;

  @override
  String get description => '创建一篇图文并茂的笔记。'
      '提供标题、正文（Markdown）、以及需要配图的描述列表，工具会自动生图并嵌入笔记中保存。'
      '适用于用户要求"写一篇文章/攻略/报告并配图"的场景。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': '笔记标题，简洁概括主题',
          },
          'content': {
            'type': 'string',
            'description': '笔记正文，支持 Markdown 格式',
          },
          'image_descriptions': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '需要生成的图片描述列表，每项为一个精炼的英文图 prompt（如 "A serene mountain landscape at sunset, digital art"）',
          },
        },
        'required': ['title', 'content'],
      };

  AgnesImageTool? _imageTool;

  AgnesImageTool _getImageTool() {
    if (_imageTool != null) return _imageTool!;
    final key = CryptoUtil.decrypt(dotenv.env['AGNES_API_KEY'] ?? '');
    _imageTool = AgnesImageTool()..apiKey = key;
    return _imageTool!;
  }

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final title = args['title'] as String? ?? '无标题笔记';
    var content = args['content'] as String? ?? '';
    final descriptions =
        (args['image_descriptions'] as List?)?.cast<String>() ?? [];

    final imageUrls = <String>[];
    final failedImages = <int>[];

    // 逐张生图
    for (var i = 0; i < descriptions.length; i++) {
      final desc = descriptions[i];
      try {
        final result = await _getImageTool().execute({'prompt': desc});
        final url = _extractFileUrl(result);
        if (url != null) {
          imageUrls.add(url);
        } else {
          failedImages.add(i + 1);
        }
      } catch (_) {
        failedImages.add(i + 1);
      }
    }

    // 拼接 Markdown
    final buf = StringBuffer(content);
    if (imageUrls.isNotEmpty) {
      for (final url in imageUrls) {
        buf.writeln('\n\n![配图]($url)');
      }
    }

    // 保存笔记
    final note = Note(
      id: await NoteStorage().nextId(),
      title: title,
      content: buf.toString(),
    );
    await NoteStorage().add(note);

    // 结果反馈
    final status = StringBuffer();
    status.writeln('笔记「$title」已保存');
    if (imageUrls.isNotEmpty) {
      status.writeln('成功生成 ${imageUrls.length} 张配图');
    }
    if (failedImages.isNotEmpty) {
      status.writeln('第 ${failedImages.join('、')} 张图片生成失败，剩余图片已正常嵌入');
    }
    if (imageUrls.isEmpty && failedImages.isEmpty) {
      status.writeln('（无配图）');
    }

    return status.toString().trim();
  }

  /// 从 AgnesImageTool 返回结果中提取 file:// URL
  String? _extractFileUrl(String result) {
    // 返回格式类似 "图片生成成功！\n图片 URL: file:///data/.../xxx.png"
    final match = RegExp(r'file://[^\s\n]+').firstMatch(result);
    return match?.group(0);
  }
}
