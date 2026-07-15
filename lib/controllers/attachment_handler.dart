import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 附件编码结果。
class AttachmentEncoded {
  final String? base64;
  final String? name;
  final String displayText;
  const AttachmentEncoded({
    required this.base64,
    required this.name,
    required this.displayText,
  });
}

/// 附件编码——从文件读取字节并编码为 base64。
/// 失败时返回 null base64，不阻断消息发送。
Future<AttachmentEncoded> encodeAttachment({
  required File? file,
  required String originalText,
  required String? attachmentType,
}) async {
  if (file == null) {
    return AttachmentEncoded(
      base64: null,
      name: null,
      displayText: originalText,
    );
  }
  try {
    final bytes = await file.readAsBytes();
    final base64 = base64Encode(bytes);
    final name = file.path.split(Platform.pathSeparator).last;
    final typeLabel = attachmentType == 'image' ? '图片' : '文档';
    final displayText = originalText.isEmpty
        ? '[附件: $typeLabel $name]'
        : '$originalText\n[附件: $typeLabel $name]';
    return AttachmentEncoded(
      base64: base64,
      name: name,
      displayText: displayText,
    );
  } catch (e) {
    debugPrint('附件读取失败，已忽略: $e');
    return AttachmentEncoded(
      base64: null,
      name: null,
      displayText: originalText,
    );
  }
}
