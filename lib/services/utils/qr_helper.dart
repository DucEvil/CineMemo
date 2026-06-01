import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrHelper {
  static String buildTicketPayload({
    required String bookingId,
    required String showtimeId,
    required String userId,
  }) {
    final raw =
        '$bookingId|$showtimeId|$userId|${DateTime.now().toIso8601String()}';
    return base64UrlEncode(utf8.encode(raw));
  }

  static Widget buildQr({required String data, double size = 180}) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF0C1A2B),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF0C1A2B),
      ),
    );
  }
}
