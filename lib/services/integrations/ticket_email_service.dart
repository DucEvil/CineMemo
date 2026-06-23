import 'package:dio/dio.dart';

import '../../config/app_config.dart';

class TicketEmailResult {
  const TicketEmailResult({
    required this.attempted,
    required this.success,
    this.message,
  });

  final bool attempted;
  final bool success;
  final String? message;

  static const skipped = TicketEmailResult(attempted: false, success: false);
}

class TicketEmailService {
  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute - $day/$month/${local.year}';
  }

  String _formatVnd(double value) {
    final integer = value.round().toString();
    final withSeparator = integer.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return '$withSeparator VND';
  }

  Future<TicketEmailResult> sendTicketEmail({
    required String recipientEmail,
    required String bookingId,
    required String ticketCode,
    required String qrPayload,
    required String movieTitle,
    required String theaterName,
    required String showtimeLabel,
    required List<String> seats,
    required double totalPrice,
    DateTime? showStartAt,
  }) async {
    final normalizedRecipient = recipientEmail.trim();
    if (normalizedRecipient.isEmpty) {
      return const TicketEmailResult(
        attempted: false,
        success: false,
        message: 'Không có email người nhận để gửi vé.',
      );
    }

    if (!AppConfig.hasTicketEmailConfig) {
      return const TicketEmailResult(
        attempted: false,
        success: false,
        message: 'Chưa cấu hình Cloud Function gửi email vé.',
      );
    }

    return await _sendTicketEmailViaFunction(
      recipientEmail: normalizedRecipient,
      bookingId: bookingId,
      ticketCode: ticketCode,
      qrPayload: qrPayload,
      movieTitle: movieTitle,
      theaterName: theaterName,
      showtimeLabel: showtimeLabel,
      seats: seats,
      totalPrice: totalPrice,
      showStartAt: showStartAt,
    );
  }

  Future<TicketEmailResult> _sendTicketEmailViaFunction({
    required String recipientEmail,
    required String bookingId,
    required String ticketCode,
    required String qrPayload,
    required String movieTitle,
    required String theaterName,
    required String showtimeLabel,
    required List<String> seats,
    required double totalPrice,
    DateTime? showStartAt,
  }) async {
    if (!AppConfig.hasTicketEmailFunction) {
      return const TicketEmailResult(
        attempted: false,
        success: false,
        message: 'Cloud Function gửi email chưa được cấu hình.',
      );
    }

    final dio = Dio();
    try {
      final response = await dio.post(
        AppConfig.ticketEmailFunctionUrl,
        data: {
          'recipientEmail': recipientEmail,
          'bookingId': bookingId,
          'ticketCode': ticketCode,
          'qrPayload': qrPayload,
          'movieTitle': movieTitle,
          'theaterName': theaterName,
          'showtimeLabel': showtimeLabel,
          'seats': seats,
          'totalPrice': totalPrice,
          if (showStartAt != null) 'showStartAt': showStartAt.toIso8601String(),
        },
      );

      final data = response.data;
      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        final success = data['success'] == true;
        final message =
            data['message']?.toString() ??
            (success ? 'Email vé đã được gửi.' : 'Gửi email thất bại.');
        return TicketEmailResult(
          attempted: true,
          success: success,
          message: message,
        );
      }

      return TicketEmailResult(
        attempted: true,
        success: false,
        message: 'Gửi email thất bại: response không hợp lệ.',
      );
    } on DioException catch (error) {
      return TicketEmailResult(
        attempted: true,
        success: false,
        message:
            'Gửi email thất bại: ${error.message ?? 'Lỗi kết nối đến server.'}',
      );
    } catch (error) {
      return TicketEmailResult(
        attempted: true,
        success: false,
        message: 'Gửi email thất bại: ${error.toString()}',
      );
    }
  }
}
