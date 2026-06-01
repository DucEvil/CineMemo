import 'package:flutter/material.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.bookingId,
    required this.showtimeId,
    required this.seats,
    required this.totalPrice,
    this.ticketCode,
    this.showTicketCode = false,
    this.isUsed = false,
    this.createdAt,
    this.onTap,
  });

  final String bookingId;
  final String showtimeId;
  final List<String> seats;
  final double totalPrice;
  final String? ticketCode;
  final bool showTicketCode;
  final bool isUsed;
  final DateTime? createdAt;
  final VoidCallback? onTap;

  static String _formatVnd(double value) {
    final integer = value.round().toString();
    final withSeparator = integer.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return '$withSeparator VND';
  }

  @override
  Widget build(BuildContext context) {
    final normalizedTicketCode = ticketCode?.trim() ?? '';
    final hasTicketCode = showTicketCode && normalizedTicketCode.isNotEmpty;
    final showBookingId = !hasTicketCode || normalizedTicketCode != bookingId;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isUsed ? 'Vé đã sử dụng' : 'Vé chưa sử dụng',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isUsed
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isUsed ? 'Đã dùng' : 'Chưa dùng',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isUsed
                          ? const Color(0xFF334155)
                          : const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (hasTicketCode) Text('Mã vé: $normalizedTicketCode'),
            if (hasTicketCode) const SizedBox(height: 4),
            if (showBookingId) Text('Mã đặt chỗ: $bookingId'),
            if (showBookingId) const SizedBox(height: 4),
            Text('Mã suất chiếu: $showtimeId'),
            const SizedBox(height: 4),
            Text('Ghế: ${seats.join(', ')}'),
            const SizedBox(height: 4),
            Text('Tổng tiền: ${_formatVnd(totalPrice)}'),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Thời gian tạo: ${createdAt!.toLocal()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 14,
                      color: Color(0xFF0F766E),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Nhấn để mở mã vé quét cổng',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
