import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../tools/base_tool.dart';

class AgnesImageTool extends AgentTool {
  /// API Key for Agnes AI (set via settings)
  String? apiKey;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  @override
  String get name => 'generate_image';

  @override
  String get description => '使用 AI 生成图片。支持根据文本描述生成图片（文生图），也支持基于已有图片进行风格转换或编辑（图生图）。当用户要求生成、创建、画一张图片时使用此工具。';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'prompt': {
        'type': 'string',
        'description': '图片生成提示词。描述主体、场景、风格、光照、构图和质量要求。例如: "A futuristic city at sunset, neon lights, cinematic realism, wide-angle"',
      },
      'size': {
        'type': 'string',
        'description': '输出图片尺寸，格式为 宽x高。常用值: 1024x768, 768x1024, 1024x1024。默认 1024x768',
      },
      'image_url': {
        'type': 'string',
        'description': '输入图片的公网 URL，用于图生图（基于已有图片进行风格转换或编辑）。留空则为文生图',
      },
    },
    'required': ['prompt'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    if (apiKey == null || apiKey!.isEmpty) {
      return '图片生成需要配置 API Key。请在设置中提供 Agnes AI 的 API Key。';
    }

    final prompt = args['prompt'] as String?;
    if (prompt == null || prompt.isEmpty) {
      return '错误: 请提供图片描述（prompt）';
    }

    final size = args['size'] as String? ?? '1024x768';
    final imageUrl = args['image_url'] as String?;

    try {
      final body = <String, dynamic>{
        'model': 'agnes-image-2.1-flash',
        'prompt': prompt,
        'size': size,
      };

      // Request base64 for reliable delivery (no extra network request by client)
      if (imageUrl != null && imageUrl.isNotEmpty) {
        body['extra_body'] = {
          'image': [imageUrl],
          'response_format': 'b64_json',
        };
      } else {
        body['return_base64'] = true;
      }

      final response = await _dio.post(
        'https://apihub.agnes-ai.com/v1/images/generations',
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
        data: body,
      );

      final data = response.data;
      final imageData = (data['data'] as List?)?.firstOrNull;
      if (imageData == null) {
        return '图片生成失败：未收到图片数据';
      }

      // Try URL first, fallback to base64
      final imageResultUrl = imageData['url'] as String?;
      final b64 = imageData['b64_json'] as String?;

      // Save base64 to temp file for guaranteed local rendering
      if (b64 != null && b64.isNotEmpty) {
        final bytes = base64Decode(b64);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/agnes_img_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes);
        final type = imageUrl != null ? '图生图' : '文生图';
        return '[$type] 图片已生成\n\n![生成的图片](file://${file.path})';
      }

      // Fallback to URL
      if (imageResultUrl != null && imageResultUrl.isNotEmpty) {
        final type = imageUrl != null ? '图生图' : '文生图';
        return '[$type] 图片已生成\n\n![生成的图片]($imageResultUrl)';
      }

      return '图片生成失败：API 未返回图片数据';
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) return 'API Key 无效，请检查配置';
      if (code == 400) return '请求参数错误: ${e.response?.data}';
      if (code == 429) return '请求过于频繁，请稍后再试';
      return '图片生成请求失败 (${code ?? e.type.name})';
    } catch (e) {
      return '图片生成错误: $e';
    }
  }
}
