import 'package:dio/dio.dart';

import '../firebase/firebase_auth_service.dart';

class GoogleCalendarSyncResult {
  const GoogleCalendarSyncResult({
    required this.attempted,
    required this.success,
    this.message,
    this.eventId,
  });

  final bool attempted;
  final bool success;
  final String? message;
  final String? eventId;

  static const skipped = GoogleCalendarSyncResult(
    attempted: false,
    success: false,
  );
}

class GoogleCalendarService {
  GoogleCalendarService({required FirebaseAuthService authService, Dio? dio})
    : _authService = authService,
      _dio = dio ?? Dio();

  static const String _calendarScope =
      'https://www.googleapis.com/auth/calendar.events';

  final FirebaseAuthService _authService;
  final Dio _dio;

  String _extractServerMessage(dynamic data) {
    if (data == null) {
      return '';
    }
    if (data is String) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final errorNode = data['error'];
      if (errorNode is Map<String, dynamic>) {
        final message = errorNode['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      return data.toString();
    }
    return data.toString();
  }

  String _friendlyDioErrorMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    final serverMessage = _extractServerMessage(
      error.response?.data,
    ).toLowerCase();

    if (statusCode == 401) {
      return 'Google Calendar hết hạn đăng nhập. Vui lòng đăng nhập Google lại.';
    }

    if (statusCode == 403 &&
        (serverMessage.contains('has not been used in project') ||
            serverMessage.contains('accessnotconfigured') ||
            serverMessage.contains('usagelimits'))) {
      return 'Google Calendar API chưa được bật cho project. Bạn vẫn đặt vé thành công.';
    }

    if (statusCode == 403) {
      return 'Không đủ quyền đồng bộ Google Calendar. Bạn vẫn đặt vé thành công.';
    }

    if (statusCode == 429) {
      return 'Google Calendar đang quá tải. Vui lòng thử lại sau.';
    }

    if (statusCode != null && statusCode >= 500) {
      return 'Google Calendar tạm thời lỗi máy chủ. Vui lòng thử lại sau.';
    }

    return 'Đồng bộ Google Calendar thất bại. Bạn vẫn đặt vé thành công.';
  }

  Future<GoogleCalendarSyncResult> createBookingEvent({
    required String summary,
    required String description,
    required DateTime startAt,
    required DateTime endAt,
    String? location,
  }) async {
    if (!_authService.isGoogleUserSignedIn) {
      return GoogleCalendarSyncResult.skipped;
    }

    final accessToken = await _authService.getGoogleAccessToken(
      requiredScopes: const [_calendarScope],
    );
    if (accessToken == null || accessToken.trim().isEmpty) {
      return const GoogleCalendarSyncResult(
        attempted: true,
        success: false,
        message:
            'Không lấy được quyền Google Calendar. ạn vẫn đặt vé thành công.',
      );
    }

    final payload = <String, dynamic>{
      'summary': summary,
      'description': description,
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      'start': {
        'dateTime': startAt.toLocal().toIso8601String(),
        'timeZone': 'Asia/Ho_Chi_Minh',
      },
      'end': {
        'dateTime': endAt.toLocal().toIso8601String(),
        'timeZone': 'Asia/Ho_Chi_Minh',
      },
      'reminders': {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 60},
          {'method': 'popup', 'minutes': 15},
        ],
      },
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events',
        data: payload,
        options: Options(
          headers: <String, String>{
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      final eventId = response.data?['id'] as String?;
      return GoogleCalendarSyncResult(
        attempted: true,
        success: true,
        message: 'Đã thêm lịch chiếu vào Google Calendar.',
        eventId: eventId,
      );
    } on DioException catch (error) {
      return GoogleCalendarSyncResult(
        attempted: true,
        success: false,
        message: _friendlyDioErrorMessage(error),
      );
    } catch (error) {
      return GoogleCalendarSyncResult(
        attempted: true,
        success: false,
        message: 'Đồng bộ Google Calendar thất bại. Bạn vẫn đặt vé thành công.',
      );
    }
  }
}
