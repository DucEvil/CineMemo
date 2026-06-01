import 'package:cloudinary_public/cloudinary_public.dart';

import '../../config/app_config.dart';

class CloudinaryService {
  CloudinaryService({CloudinaryPublic? cloudinary}) : _cloudinary = cloudinary;

  CloudinaryPublic? _cloudinary;

  bool get isConfigured => AppConfig.hasCloudinaryConfig;

  CloudinaryPublic? get _client {
    final current = _cloudinary;
    if (current != null) {
      return current;
    }
    if (!isConfigured) {
      return null;
    }

    _cloudinary = CloudinaryPublic(
      AppConfig.cloudinaryCloudName,
      AppConfig.cloudinaryUploadPreset,
      cache: false,
    );
    return _cloudinary;
  }

  Future<String?> uploadImage({
    required String filePath,
    String folder = 'cinememo',
  }) async {
    final client = _client;
    if (client == null) {
      return null;
    }

    try {
      final response = await client.uploadFile(
        CloudinaryFile.fromFile(
          filePath,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (_) {
      return null;
    }
  }
}
