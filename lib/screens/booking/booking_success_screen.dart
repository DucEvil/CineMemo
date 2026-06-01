import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/booking_provider.dart';
import '../../utils/app_routes.dart';
import '../../widgets/common/qr_ticket_display.dart';

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final bookingProvider = Provider.of<BookingProvider>(context);

    String bookingId = '';
    String qrPayload = '';

    if (args is Map<String, dynamic>) {
      bookingId = (args['bookingId'] as String?) ?? '';
      qrPayload = (args['qrPayload'] as String?) ?? '';
    }

    bookingId = bookingId.isNotEmpty
        ? bookingId
        : (bookingProvider.lastBookingId ?? '');
    qrPayload = qrPayload.isNotEmpty
        ? qrPayload
        : (bookingProvider.lastQrPayload ?? '');

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đặt vé thành công'),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            const Icon(
              Icons.verified_rounded,
              size: 62,
              color: Color(0xFF16A34A),
            ),
            const SizedBox(height: 10),
            const Text(
              'Thanh toán thành công',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Vé của bạn đã được tạo và lưu vào hệ thống.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            if (bookingId.isNotEmpty && qrPayload.isNotEmpty)
              QrTicketDisplay(bookingId: bookingId, qrPayload: qrPayload)
            else
              const Text('Thiếu dữ liệu mã QR vé.'),
            if (bookingProvider.calendarSyncMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  bookingProvider.calendarSyncMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: bookingProvider.calendarSynced
                        ? const Color(0xFF166534)
                        : const Color(0xFFB45309),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (bookingProvider.ticketEmailMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  bookingProvider.ticketEmailMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: bookingProvider.ticketEmailSent
                        ? const Color(0xFF166534)
                        : const Color(0xFFB45309),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (bookingProvider.showtimeReminderMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  bookingProvider.showtimeReminderMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: bookingProvider.showtimeReminderScheduled
                        ? const Color(0xFF166534)
                        : const Color(0xFFB45309),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.booking,
                        (route) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Vào vé của tôi'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.movieList,
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Về trang chủ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
