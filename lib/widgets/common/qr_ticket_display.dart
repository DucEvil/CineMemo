import 'package:flutter/material.dart';

import '../../services/utils/qr_helper.dart';

class QrTicketDisplay extends StatelessWidget {
  const QrTicketDisplay({
    super.key,
    required this.bookingId,
    required this.qrPayload,
  });

  final String bookingId;
  final String qrPayload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            'Booking ID: $bookingId',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          QrHelper.buildQr(data: qrPayload),
          const SizedBox(height: 12),
          const Text(
            'Show this QR code at cinema check-in.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
