import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/media_item.dart';
import '../core/service_locator.dart';
import '../services/media_storage.dart';
import '../tools/base_tool.dart';
import 'agnes_video_tool.g.dart';

class AgnesVideoTool extends AgentTool {
  final String? apiKey;

  AgnesVideoTool({this.apiKey});

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
    ),
  );

  @override
  String get name => 'generate_video';

  @override
  String get description => agnesVideoToolDescription;

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'prompt': {
        'type': 'string',
        'description': '视频内容描述。包括主体、动作、场景、镜头运动、光照和视觉风格',
      },
      'image_url': {
        'type': 'string',
        'description':
            '输入图片的 URL 或 base64 编码（data:image/png;base64,...格式），用于图生视频。留空则为文生视频',
      },
      'duration': {
        'type': 'string',
        'description': '视频时长: short(约3秒), medium(约5秒), long(约10秒)。默认 medium',
      },
    },
    'required': ['prompt'],
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    if (apiKey == null || apiKey!.isEmpty) {
      return '视频生成需要配置 API Key';
    }

    final prompt = args['prompt'] as String?;
    if (prompt == null || prompt.isEmpty) {
      return '错误: 请提供视频描述（prompt）';
    }

    final imageUrl = args['image_url'] as String?;
    final duration = args['duration'] as String? ?? 'medium';

    // Map duration to frames
    final (numFrames, _) = switch (duration) {
      'short' => (81, 24),
      'long' => (241, 24),
      _ => (121, 24),
    };

    try {
      // Step 1: Create video task
      final body = <String, dynamic>{
        'model': 'agnes-video-v2.0',
        'prompt': prompt,
        'num_frames': numFrames,
        'frame_rate': 24,
      };

      if (imageUrl != null && imageUrl.isNotEmpty) {
        body['image'] = imageUrl;
      }

      final createResp = await _dio.post(
        'https://apihub.agnes-ai.com/v1/videos',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: body,
      );

      final videoId = createResp.data['video_id'] as String?;
      if (videoId == null || videoId.isEmpty) {
        return '视频任务创建失败：未收到 video_id';
      }

      // Step 2: Poll for completion
      const maxAttempts = 120; // 10 minutes at 5s intervals
      for (var i = 0; i < maxAttempts; i++) {
        await Future.delayed(const Duration(seconds: 5));

        final queryResp = await _dio.get(
          'https://apihub.agnes-ai.com/agnesapi',
          queryParameters: {'video_id': videoId},
          options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
        );

        final status = queryResp.data['status'] as String?;
        final progress = queryResp.data['progress'] as int? ?? 0;

        if (status == 'completed') {
          // Try multiple possible URL fields from the API response
          final videoUrl =
              (queryResp.data['url'] as String?) ??
              (queryResp.data['video_url'] as String?) ??
              (queryResp.data['output_url'] as String?) ??
              (queryResp.data['download_url'] as String?) ??
              (queryResp.data['remixed_from_video_id'] as String?);
          if (videoUrl == null || videoUrl.isEmpty) {
            return '视频生成完成但未返回下载地址: ${queryResp.data.keys.join(', ')}';
          }

          // Download video to temp (for playback) and docs (for storage)
          final tempDir = await getTemporaryDirectory();
          final docsDir = await getApplicationDocumentsDirectory();
          final fileName =
              'agnes_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final tempFile = File('${tempDir.path}/$fileName');
          await _dio.download(videoUrl, tempFile.path);
          // Copy to permanent storage
          final docsFile = await tempFile.copy('${docsDir.path}/$fileName');
          await getIt<MediaStorage>().add(
            MediaItem(
              id: const Uuid().v4(),
              type: MediaType.video,
              filePath: docsFile.path,
              prompt: prompt,
            ),
          );

          final type = imageUrl != null ? '图生视频' : '文生视频';
          return '[$type] 视频已生成\n\n![生成的视频](file://${docsFile.path})';
        }

        if (status == 'failed') {
          final error = queryResp.data['error'];
          return '视频生成失败: $error';
        }

        // Still processing — continue polling
        if (i % 4 == 3) {
          // Yield progress info every ~20s (the tool can't yield mid-execution, but this keeps the process alive)
        }
      }

      return '视频生成超时（等待超过10分钟）';
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) return 'API Key 无效，请检查配置';
      if (code == 400) return '请求参数错误: ${e.response?.data}';
      return '视频生成请求失败 (${code ?? e.type.name})';
    } catch (e) {
      return '视频生成错误: $e';
    }
  }
}
