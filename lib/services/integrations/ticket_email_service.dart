import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

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
  static const String _gmailSmtpHost = 'smtp.gmail.com';

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
        message: 'Chưa cấu hình SMTP gửi email vé.',
      );
    }

    final smtpHost = AppConfig.ticketEmailSmtpHost.trim().toLowerCase();
    if (smtpHost != _gmailSmtpHost) {
      return const TicketEmailResult(
        attempted: false,
        success: false,
        message: 'Chỉ hỗ trợ gửi vé qua Gmail SMTP (smtp.gmail.com).',
      );
    }

    final senderEmail = AppConfig.ticketEmailSenderEmail.trim().isNotEmpty
        ? AppConfig.ticketEmailSenderEmail.trim()
        : AppConfig.ticketEmailSmtpUsername.trim();

    final smtpServer = SmtpServer(
      _gmailSmtpHost,
      port: AppConfig.ticketEmailSmtpPort,
      ssl: AppConfig.ticketEmailSmtpUseSsl,
      username: AppConfig.ticketEmailSmtpUsername.trim(),
      password: AppConfig.ticketEmailSmtpPassword,
    );

    final barcodeUrl =
        'https://bwipjs-api.metafloor.com/?bcid=code128&includetext&scale=3&text=${Uri.encodeQueryComponent(ticketCode)}';
    final qrUrl =
        'https://quickchart.io/qr?size=220&text=${Uri.encodeQueryComponent(qrPayload)}';
    final seatLabel = seats.isEmpty ? 'Chua xac dinh' : seats.join(', ');
    final showtimeText = showStartAt != null
        ? _formatDateTime(showStartAt)
        : showtimeLabel;

    final message = Message()
      ..from = Address(senderEmail, AppConfig.ticketEmailSenderName)
      ..recipients.add(normalizedRecipient)
      ..subject = 'Vé xem phim $movieTitle - CineMemo'
      ..html =
          '''
<div style="font-family:Arial,sans-serif;line-height:1.6;color:#0f172a;">
  <h2 style="margin:0 0 10px;">Vé điện tử CineMemo</h2>
  <p style="margin:0 0 12px;">Cảm ơn bạn đã đặt vé. Đây là thông tin vé của bạn:</p>
  <ul style="padding-left:18px;margin:0 0 12px;">
    <li><strong>Mã đặt vé:</strong> $bookingId</li>
    <li><strong>Mã vé:</strong> $ticketCode</li>
    <li><strong>Phim:</strong> $movieTitle</li>
    <li><strong>Rạp:</strong> $theaterName</li>
    <li><strong>Suất chiếu:</strong> $showtimeText</li>
    <li><strong>Ghế:</strong> $seatLabel</li>
    <li><strong>Tổng tiền:</strong> ${_formatVnd(totalPrice)}</li>
  </ul>
  <p style="margin:12px 0 6px;"><strong>Mã vạch vé:</strong></p>
  <img src="$barcodeUrl" alt="ticket barcode" style="max-width:100%;height:auto;border:1px solid #e2e8f0;padding:6px;background:#ffffff;" />
  <p style="margin:12px 0 6px;"><strong>Mã QR check-in:</strong></p>
  <img src="$qrUrl" alt="ticket qr" style="max-width:220px;height:auto;border:1px solid #e2e8f0;padding:6px;background:#ffffff;" />
</div>
''';

    try {
      await send(message, smtpServer);
      return const TicketEmailResult(
        attempted: true,
        success: true,
        message: 'Đã gửi vé qua email thành công.',
      );
    } on MailerException catch (error) {
      final detail = error.problems.isNotEmpty
          ? (error.problems.first.msg.isNotEmpty
                ? error.problems.first.msg
                : error.problems.first.code.toString())
          : '';
      final message = detail.isNotEmpty
          ? 'Gửi email thất bại: $detail'
          : 'Gửi email thất bại. Vui lòng kiểm tra cấu hình SMTP.';

      return TicketEmailResult(
        attempted: true,
        success: false,
        message: message,
      );
    } catch (_) {
      return const TicketEmailResult(
        attempted: true,
        success: false,
        message: 'Gửi email thất bại. Vui lòng thử lại sau.',
      );
    }
  }
}
