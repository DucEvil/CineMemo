import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/utils/qr_helper.dart';
import '../../utils/app_routes.dart';

class MomoQrPaymentScreen extends StatefulWidget {
  const MomoQrPaymentScreen({super.key});

  @override
  State<MomoQrPaymentScreen> createState() => _MomoQrPaymentScreenState();
}

class _MomoQrPaymentScreenState extends State<MomoQrPaymentScreen> {
  static const String _momoQrAssetPath = 'assets/images/momo_qr.png';

  late final String _transferContent;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final showtimeId = args['showtimeId'] as String? ?? '';
      _transferContent = _buildTransferContent(showtimeId: showtimeId);
      return;
    }

    _transferContent = _buildTransferContent(showtimeId: 'unknown');
  }

  String _buildTransferContent({required String showtimeId}) {
    final normalized = showtimeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final suffix = normalized.isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString().substring(7)
        : (normalized.length > 8
              ? normalized.substring(normalized.length - 8)
              : normalized);
    return 'CINEMEMO-$suffix';
  }

  String _buildMomoQrData(double amount) {
    final payload = AppConfig.momoPersonalQrPayload.trim();
    if (payload.isEmpty) {
      return 'MOMO|${AppConfig.momoPersonalPhone}|${amount.round()}|$_transferContent';
    }

    return payload
        .replaceAll('{amount}', amount.round().toString())
        .replaceAll('{content}', _transferContent);
  }

  bool _supportsDynamicQrPayload(String payload) {
    final normalized = payload.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    return normalized.startsWith('000201') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('momo://');
  }

  static String _formatVnd(double value) {
    final integer = value.round().toString();
    final withSeparator = integer.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return '$withSeparator VND';
  }

  Widget _buildMomoQrWidget({
    required String qrData,
    required bool useDynamicPersonalQr,
  }) {
    const qrSize = 220.0;
    if (useDynamicPersonalQr) {
      return QrHelper.buildQr(data: qrData, size: qrSize);
    }

    return Image.asset(
      _momoQrAssetPath,
      width: qrSize,
      height: qrSize,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return QrHelper.buildQr(data: qrData, size: qrSize);
      },
    );
  }

  DateTime? _extractShowStartAtFromArgs(Map<String, dynamic> args) {
    final showStartAtRaw = args['showStartAt'];
    if (showStartAtRaw is DateTime) {
      return showStartAtRaw;
    }
    if (showStartAtRaw is String && showStartAtRaw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(showStartAtRaw);
      if (parsed != null) {
        return parsed;
      }
    }

    final showDateRaw = args['showDate'];
    final showtimeLabel = (args['showtimeLabel'] as String? ?? '').trim();
    if (showDateRaw is String && showDateRaw.trim().isNotEmpty) {
      final showDate = DateTime.tryParse(showDateRaw);
      if (showDate != null) {
        final timeMatch = RegExp(
          r'(\d{1,2}):(\d{2})',
        ).firstMatch(showtimeLabel);
        if (timeMatch != null) {
          final hour = int.tryParse(timeMatch.group(1) ?? '0') ?? 0;
          final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
          return DateTime(
            showDate.year,
            showDate.month,
            showDate.day,
            hour,
            minute,
          );
        }
      }
    }

    final showtimeId = (args['showtimeId'] as String? ?? '').trim();
    final match = RegExp(r'(\d{8})-(\d{2}):(\d{2})$').firstMatch(showtimeId);
    if (match == null) {
      return null;
    }

    final dateRaw = match.group(1)!;
    final year = int.tryParse(dateRaw.substring(0, 4));
    final month = int.tryParse(dateRaw.substring(4, 6));
    final day = int.tryParse(dateRaw.substring(6, 8));
    final hour = int.tryParse(match.group(2)!);
    final minute = int.tryParse(match.group(3)!);

    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    return DateTime(year, month, day, hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, dynamic>) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thanh toán QR MoMo')),
        body: const Center(child: Text('Thiếu dữ liệu thanh toán.')),
      );
    }

    final totalPrice =
        (args['payableTotal'] as num?)?.toDouble() ??
        (args['totalPrice'] as num?)?.toDouble() ??
        0;
    final showtimeId = args['showtimeId'] as String? ?? '';
    final showtimeLabel = args['showtimeLabel'] as String? ?? '--:--';
    final movieTitle = args['movieTitle'] as String? ?? 'Phim';
    final theaterName = args['theaterName'] as String? ?? 'Chưa rõ rạp';
    final theaterAddress =
        args['theaterAddress'] as String? ?? 'Chưa có địa chỉ rạp';
    final showDateLabel = args['showDateLabel'] as String? ?? '';
    final movieDuration = (args['movieDuration'] as num?)?.toInt() ?? 0;
    final selectedSeats =
        (args['selectedSeats'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final comboItems =
        (args['comboItems'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        const <Map<String, dynamic>>[];
    final comboTotal = (args['comboTotal'] as num?)?.toDouble() ?? 0;
    final showStartAt = _extractShowStartAtFromArgs(args);
    final usePersonalQrMode = AppConfig.useMomoPersonalQrMode;
    final isWebGatewayFallback = kIsWeb && !usePersonalQrMode;
    final dynamicPayload = AppConfig.momoPersonalQrPayload;
    final useDynamicPersonalQr =
        usePersonalQrMode && _supportsDynamicQrPayload(dynamicPayload);

    final bookingProvider = Provider.of<BookingProvider>(context);
    final qrData = _buildMomoQrData(totalPrice);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          usePersonalQrMode
              ? 'Thanh toán MoMo cá nhân'
              : 'Thanh toán MoMo Sandbox',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movieTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Suất chiếu: $showtimeLabel'),
                const SizedBox(height: 4),
                Text(
                  'Số tiền: ${_formatVnd(totalPrice)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Nội dung CK: $_transferContent'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildMomoQrWidget(
                  qrData: qrData,
                  useDynamicPersonalQr: useDynamicPersonalQr,
                ),
                const SizedBox(height: 12),
                Text(
                  usePersonalQrMode
                      ? (useDynamicPersonalQr
                            ? 'Mở app MoMo của bạn và quét QR để điền nhanh thông tin.'
                            : 'Mở app MoMo của bạn và quét QR ở trên để chuyển khoản.')
                      : (isWebGatewayFallback
                            ? 'MoMo gateway chưa hỗ trợ trên Web. Hãy quét QR và xác nhận thủ công để hoàn tất đặt vé.'
                            : 'Nhấn nút bên dưới để mở app MoMo thanh toán.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  usePersonalQrMode
                      ? (useDynamicPersonalQr
                            ? 'Sau khi chuyển khoản, bấm xác nhận để hoàn tất đặt vé.'
                            : 'Neu app khong tu dien so tien/noi dung, vui long nhap theo thong tin o tren.')
                      : (isWebGatewayFallback
                            ? 'Ghi chú: chế độ này dùng để mô phỏng trên web, không gọi callback MoMo thật.'
                            : 'Sau khi hoàn tất, ứng dụng sẽ nhận callback deep link và tự xác nhận giao dịch.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tài khoản nhận: ${AppConfig.momoPersonalName} - ${AppConfig.momoPersonalPhone}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isWebGatewayFallback)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: const Text(
                'MoMo chưa hỗ trợ web trong app hiện tại. Khi nhấn nút bên dưới, hệ thống sẽ xác nhận thanh toán theo chế độ web fallback.',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (bookingProvider.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                bookingProvider.error!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: bookingProvider.processingPayment
                  ? null
                  : () async {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final uid = (auth.uid ?? '').trim();
                      if (uid.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Vui lòng đăng nhập lại trước khi thanh toán.',
                            ),
                          ),
                        );
                        return;
                      }

                      final bookingDetails = <String, dynamic>{
                        'movieTitle': movieTitle,
                        'theaterName': theaterName,
                        'theaterAddress': theaterAddress,
                        'showtimeLabel': showtimeLabel,
                        'showDateLabel': showDateLabel,
                        'movieDuration': movieDuration,
                        'comboItems': comboItems,
                        'comboTotal': comboTotal,
                        'ticketCount': selectedSeats.isNotEmpty
                            ? selectedSeats.length
                            : ((args['ticketCount'] as num?)?.toInt() ?? 0),
                        'paymentMethod': usePersonalQrMode
                            ? 'MoMo Personal QR'
                            : (isWebGatewayFallback
                                  ? 'MoMo Web Fallback'
                                  : 'MoMo Sandbox'),
                        'userEmail': auth.email,
                        'userDisplayName': auth.displayName,
                        'isGoogleAccount': auth.isGoogleAccount,
                      };
                      if (showStartAt != null) {
                        bookingDetails['showStartAt'] = showStartAt;
                      }

                      final success = await Provider.of<BookingProvider>(context, listen: false)
                          .checkout(
                            userId: uid,
                            showtimeId: showtimeId,
                            totalPrice: totalPrice,
                            bookingDetails: bookingDetails,
                            skipPaymentGateway:
                                usePersonalQrMode || isWebGatewayFallback,
                          );

                      if (!success || !context.mounted) {
                        return;
                      }

                      Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.bookingSuccess,
                        arguments: {
                          'bookingId': Provider.of<BookingProvider>(context, listen: false)
                              .lastBookingId,
                          'qrPayload': Provider.of<BookingProvider>(context, listen: false)
                              .lastQrPayload,
                        },
                      );
                    },
              icon: bookingProvider.processingPayment
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                bookingProvider.processingPayment
                    ? (usePersonalQrMode
                          ? 'Đang xác nhận thanh toán...'
                          : 'Đang xử lý thanh toán...')
                    : (usePersonalQrMode
                          ? 'Tôi đã chuyển khoản xong'
                          : (isWebGatewayFallback
                                ? 'Xác nhận thanh toán (Web)'
                                : 'Thanh toán qua app MoMo')),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
