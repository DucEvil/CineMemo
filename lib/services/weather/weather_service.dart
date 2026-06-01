import '../../config/app_config.dart';
import '../api/dio_client.dart';
import '../api/endpoints.dart';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperature,
    required this.description,
    required this.iconCode,
    required this.city,
  });

  final double temperature;
  final String description;
  final String iconCode;
  final String city;
}

class WeatherService {
  WeatherService({DioClient? client})
    : _client = client ?? DioClient(baseUrl: AppConfig.weatherApiBaseUrl);

  final DioClient _client;

  Future<WeatherSnapshot?> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    if (!AppConfig.hasWeatherKey) {
      return null;
    }

    try {
      final response = await _client.get(
        ApiEndpoints.weatherByCoordinate,
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'appid': AppConfig.weatherApiKey,
          'units': 'metric',
          'lang': 'vi',
        },
      );

      final payload = response.data;
      if (payload is! Map) {
        return null;
      }

      final main = payload['main'];
      final weatherList = payload['weather'];
      final weather = weatherList is List && weatherList.isNotEmpty
          ? weatherList.first
          : <String, dynamic>{};

      return WeatherSnapshot(
        temperature: (main is Map ? main['temp'] : null) is num
            ? ((main!['temp']) as num).toDouble()
            : 0,
        description:
            (weather is Map ? weather['description'] : null) as String? ??
            'Khong co mo ta',
        iconCode: (weather is Map ? weather['icon'] : null) as String? ?? '01d',
        city: payload['name'] as String? ?? 'Unknown',
      );
    } catch (_) {
      return null;
    }
  }
}
