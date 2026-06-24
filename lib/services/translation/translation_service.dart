import 'package:dio/dio.dart';

import '../../config/app_config.dart';

class TranslationService {
  TranslationService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Map<String, String> _cache = <String, String>{};

  bool get isEnabled => AppConfig.hasGoogleCloudTranslateApiKey;

  Future<String> translateText({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'vi',
  }) async {
    final normalizedText = text.trim();
    final normalizedTarget = targetLanguage.trim().toLowerCase();
    final normalizedSource = sourceLanguage.trim().toLowerCase();

    if (normalizedText.isEmpty ||
        normalizedTarget.isEmpty ||
        normalizedTarget == normalizedSource ||
        !isEnabled) {
      return text;
    }

    final cacheKey = '$normalizedTarget|$normalizedText';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final response = await _dio.post(
        '${AppConfig.googleCloudTranslateApiUrl}?key=${AppConfig.googleCloudTranslateApiKey}',
        data: {
          'q': normalizedText,
          'target': normalizedTarget,
          'format': 'text',
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final translations = data['data'] as Map<String, dynamic>?;
        final items = translations?['translations'] as List?;
        if (items != null && items.isNotEmpty) {
          final translation =
              (items.first as Map<String, dynamic>?)?['translatedText']
                  as String?;
          if (translation != null && translation.isNotEmpty) {
            _cache[cacheKey] = translation;
            return translation;
          }
        }
      }
    } catch (_) {
      // Fallback to original text when translation fails.
    }

    return text;
  }
}
