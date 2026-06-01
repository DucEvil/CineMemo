import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/firebase/firebase_firestore_service.dart';
import '../../services/utils/qr_helper.dart';
import '../../utils/app_routes.dart';
import '../../widgets/common/custom_bottom_nav_bar.dart';

class BookingHistoryScreen extends StatelessWidget {
  const BookingHistoryScreen({super.key});

  static const Duration _usedAfterShowtime = Duration(hours: 2, minutes: 30);
  static const Map<String, String> _theaterNameFallback = {
    't01': 'CineMemo Landmark 81',
    't02': 'CineMemo Thủ Đức',
    't03': 'CineMemo Quận 7',
    't04': 'CineMemo Hoàn Kiếm',
    't05': 'CineMemo Cầu Giấy',
    't06': 'CineMemo Hà Đông',
  };
  static const Map<String, String> _theaterAddressFallback = {
    't01': 'Bình Thạnh, TP.HCM',
    't02': 'Võ Văn Ngân, TP. Thủ Đức',
    't03': 'Nguyễn Hữu Thọ, Quận 7',
    't04': 'Tràng Tiền, Hoàn Kiếm, Hà Nội',
    't05': 'Trần Thái Tông, Cầu Giấy, Hà Nội',
    't06': 'Tố Hữu, Hà Đông, Hà Nội',
  };

  DateTime? _toDateTime(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    return null;
  }

  DateTime? _extractShowStartAt(Map<String, dynamic> booking) {
    final startAtRaw = booking['showStartAt'] ?? booking['showtimeStartAt'];
    final startAt = _toDateTime(startAtRaw);
    if (startAt != null) {
      return startAt;
    }

    final showDate = _toDateTime(booking['showDate']);
    final showtimeLabel = (booking['showtimeLabel'] as String? ?? '').trim();
    if (showDate != null) {
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(showtimeLabel);
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

    final showtimeId = (booking['showtimeId'] as String? ?? '').trim();
    final match = RegExp(r'(\d{8})-(\d{2}):(\d{2})$').firstMatch(showtimeId);
    if (match == null) {
      return null;
    }

    final dateRaw = match.group(1)!;
    final hourRaw = match.group(2)!;
    final minuteRaw = match.group(3)!;

    final year = int.tryParse(dateRaw.substring(0, 4));
    final month = int.tryParse(dateRaw.substring(4, 6));
    final day = int.tryParse(dateRaw.substring(6, 8));
    final hour = int.tryParse(hourRaw);
    final minute = int.tryParse(minuteRaw);

    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    return DateTime(year, month, day, hour, minute);
  }

  bool _isUsedBooking(Map<String, dynamic> booking) {
    final isUsedRaw = booking['isUsed'];
    if (isUsedRaw is bool) {
      return isUsedRaw;
    }

    final usedAtRaw = booking['usedAt'] ?? booking['checkedInAt'];
    if (usedAtRaw is Timestamp || usedAtRaw is DateTime) {
      return true;
    }
    if (usedAtRaw is String && usedAtRaw.trim().isNotEmpty) {
      return true;
    }

    final status = (booking['status'] as String? ?? '').trim().toLowerCase();
    const usedStatuses = {
      'used',
      'checked_in',
      'checkedin',
      'checked-in',
      'redeemed',
      'consumed',
      'completed',
      'done',
    };

    if (usedStatuses.contains(status)) {
      return true;
    }

    final showStartAt = _extractShowStartAt(booking);
    if (showStartAt == null) {
      return false;
    }

    final usedCutoff = showStartAt.add(_usedAfterShowtime);
    return DateTime.now().isAfter(usedCutoff);
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatDate(DateTime value) {
    return '${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year}';
  }

  String _weekdayLabel(DateTime value) {
    const weekDays = ['Th 2', 'Th 3', 'Th 4', 'Th 5', 'Th 6', 'Th 7', 'CN'];
    return weekDays[value.weekday - 1];
  }

  String _formatWeekdayDate(DateTime value) {
    return '${_weekdayLabel(value)} ${_formatDate(value)}';
  }

  String _formatTime(DateTime value) {
    return '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
  }

  String _formatDateTime(DateTime value) {
    return '${_formatTime(value)} ${_formatDate(value)}';
  }

  static String _formatVnd(double value) {
    final integer = value.round().toString();
    final withSeparator = integer.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return '$withSeparator VND';
  }

  String _bookingIdFrom(Map<String, dynamic> booking) {
    return booking['bookingId'] as String? ?? booking['id'] as String? ?? '';
  }

  String _ticketCodeFrom(Map<String, dynamic> booking) {
    final code =
        booking['ticketCode'] as String? ??
        booking['bookingId'] as String? ??
        booking['id'] as String? ??
        '';
    return code;
  }

  String _movieTitleFrom(Map<String, dynamic> booking) {
    final title = (booking['movieTitle'] as String? ?? '').trim();
    if (title.isNotEmpty) {
      return title;
    }
    return 'Phim đã đặt';
  }

  String _theaterIdFrom(Map<String, dynamic> booking) {
    final raw = (booking['showtimeId'] as String? ?? '').trim();
    if (raw.isEmpty) {
      return '';
    }
    return raw.split('-').first;
  }

  String _theaterNameFrom(Map<String, dynamic> booking) {
    final direct = (booking['theaterName'] as String? ?? '').trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    final theaterId = _theaterIdFrom(booking);
    return _theaterNameFallback[theaterId] ?? 'Chưa rõ rạp';
  }

  String _theaterAddressFrom(Map<String, dynamic> booking) {
    final direct = (booking['theaterAddress'] as String? ?? '').trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    final theaterId = _theaterIdFrom(booking);
    return _theaterAddressFallback[theaterId] ?? 'Chưa có địa chỉ rạp';
  }

  String _showtimeSummaryFrom(
    Map<String, dynamic> booking, {
    bool forceWeekdayDate = false,
  }) {
    final showStartAt = _extractShowStartAt(booking);
    if (forceWeekdayDate && showStartAt != null) {
      return '${_formatTime(showStartAt)} - ${_formatWeekdayDate(showStartAt)}';
    }

    final label = (booking['showtimeLabel'] as String? ?? '').trim();
    if (label.isNotEmpty) {
      return label;
    }

    if (showStartAt != null) {
      return '${_formatTime(showStartAt)} - ${_formatDate(showStartAt)}';
    }

    final fallback = (booking['showtimeId'] as String? ?? '').trim();
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return '--:--';
  }

  List<String> _seatCodesFrom(Map<String, dynamic> booking) {
    final seatsRaw = booking['seats'];
    if (seatsRaw is! List) {
      return const <String>[];
    }
    return seatsRaw.whereType<String>().toList();
  }

  int _ticketCountFrom(Map<String, dynamic> booking, List<String> seats) {
    final ticketCountRaw = booking['ticketCount'];
    if (ticketCountRaw is num && ticketCountRaw > 0) {
      return ticketCountRaw.toInt();
    }
    return seats.length;
  }

  List<Map<String, dynamic>> _comboItemsFrom(Map<String, dynamic> booking) {
    final combosRaw = booking['comboItems'];
    if (combosRaw is! List) {
      return const <Map<String, dynamic>>[];
    }

    return combosRaw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _comboSummaryFrom(Map<String, dynamic> booking) {
    final comboItems = _comboItemsFrom(booking);
    if (comboItems.isEmpty) {
      return 'Không chọn';
    }

    final labels = <String>[];
    for (final item in comboItems) {
      final name = (item['name'] as String? ?? '').trim();
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      if (name.isEmpty || quantity <= 0) {
        continue;
      }
      labels.add('$name x$quantity');
    }

    if (labels.isEmpty) {
      return 'Không chọn';
    }
    return labels.join(', ');
  }

  String _durationFrom(Map<String, dynamic> booking) {
    final durationRaw = booking['movieDuration'];
    final duration = (durationRaw as num?)?.toInt() ?? 0;
    if (duration <= 0) {
      return 'Chưa rõ';
    }
    return '$duration phút';
  }

  String _transactionIdFrom(Map<String, dynamic> booking) {
    final transactionId = (booking['transactionId'] as String? ?? '').trim();
    if (transactionId.isNotEmpty) {
      return transactionId;
    }

    final bookingId = _bookingIdFrom(booking);
    if (bookingId.isNotEmpty) {
      return 'GD-$bookingId';
    }
    return 'Chưa có';
  }

  DateTime? _transactionAtFrom(Map<String, dynamic> booking) {
    return _toDateTime(booking['transactionAt']) ??
        _toDateTime(booking['createdAt']);
  }

  Widget _buildDetailLine(
    String label,
    String value, {
    bool selectable = false,
  }) {
    final textStyle = const TextStyle(color: Color(0xFF0F172A));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: selectable
                ? SelectableText(value, style: textStyle)
                : Text(value, style: textStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildUsedStamp() {
    return Transform.rotate(
      angle: -0.14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFB91C1C), width: 2),
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFFFE4E6),
        ),
        child: const Text(
          'ĐÃ SỬ DỤNG',
          style: TextStyle(
            color: Color(0xFFB91C1C),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  void _showTicketDetailDialog(
    BuildContext context,
    Map<String, dynamic> booking, {
    required bool isUsed,
  }) {
    final ticketCode = _ticketCodeFrom(booking).trim();
    final qrPayload = (booking['qrPayload'] as String? ?? '').trim();
    final qrData = qrPayload.isNotEmpty ? qrPayload : ticketCode;

    if (qrData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vé này chưa có mã để quét.')),
      );
      return;
    }

    final bookingId = _bookingIdFrom(booking);
    final movieTitle = _movieTitleFrom(booking);
    final theaterName = _theaterNameFrom(booking);
    final theaterAddress = _theaterAddressFrom(booking);
    final showtime = _showtimeSummaryFrom(booking, forceWeekdayDate: isUsed);
    final duration = _durationFrom(booking);
    final seatCodes = _seatCodesFrom(booking);
    final seatText = seatCodes.isEmpty ? 'Chưa có' : seatCodes.join(', ');
    final ticketCount = _ticketCountFrom(booking, seatCodes);
    final comboSummary = _comboSummaryFrom(booking);
    final transactionAt = _transactionAtFrom(booking);
    final transactionTime = transactionAt != null
        ? _formatDateTime(transactionAt)
        : 'Chưa có';
    final transactionId = _transactionIdFrom(booking);
    final totalPrice = (booking['totalPrice'] as num?)?.toDouble() ?? 0;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          'Thông tin vé',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isUsed) _buildUsedStamp(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailLine('Tên phim', movieTitle),
                  _buildDetailLine('Thức ăn kèm', comboSummary),
                  _buildDetailLine('Số vé', '$ticketCount vé'),
                  _buildDetailLine('Mã đặt vé', bookingId, selectable: true),
                  _buildDetailLine(
                    'Mã vé',
                    ticketCode.isNotEmpty ? ticketCode : bookingId,
                    selectable: true,
                  ),
                  _buildDetailLine('Rạp', theaterName),
                  _buildDetailLine('Địa chỉ rạp', theaterAddress),
                  _buildDetailLine('Thời lượng', duration),
                  _buildDetailLine('Số ghế', seatText),
                  _buildDetailLine('Suất chiếu', showtime),
                  _buildDetailLine('Tổng tiền', _formatVnd(totalPrice)),
                  _buildDetailLine('Thời gian giao dịch', transactionTime),
                  _buildDetailLine(
                    'Mã giao dịch',
                    transactionId,
                    selectable: true,
                  ),
                  _buildDetailLine('Mã QR vé', qrData, selectable: true),
                  const SizedBox(height: 12),
                  Center(child: QrHelper.buildQr(data: qrData, size: 220)),
                  const SizedBox(height: 10),
                  const Text(
                    'Đưa mã QR này cho nhân viên để nhận vé vào rạp.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF0F766E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Đóng'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openReviewFromUsedBooking(
    BuildContext context,
    Map<String, dynamic> booking,
  ) {
    final movieTitle = _movieTitleFrom(booking);
    final movieId = (booking['movieId'] as String? ?? '').trim();

    Navigator.pushNamed(
      context,
      AppRoutes.createReview,
      arguments: {
        'movieTitle': movieTitle,
        if (movieId.isNotEmpty) 'movieId': movieId,
      },
    );
  }

  void _openUsedTicketHistory(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.booking,
      arguments: const {'historyOnly': true},
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final historyOnly =
        args is Map<String, dynamic> && args['historyOnly'] == true;
    final userId = Provider.of<AuthProvider>(context).uid;
    final bottomNav = CustomBottomNavBar(currentIndex: historyOnly ? 3 : 1);
    final title = historyOnly ? 'Lịch sử đặt chỗ' : 'Vé của tôi';

    if (userId == null || userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: historyOnly
              ? null
              : [
                  TextButton.icon(
                    onPressed: () => _openUsedTicketHistory(context),
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('Vé đã sử dụng'),
                  ),
                ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  historyOnly
                      ? 'Vui lòng đăng nhập để xem lịch sử đặt chỗ.'
                      : 'Vui lòng đăng nhập để xem vé của bạn.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.login);
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Đăng nhập'),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: bottomNav,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: historyOnly
            ? null
            : [
                TextButton.icon(
                  onPressed: () => _openUsedTicketHistory(context),
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('Vé đã sử dụng'),
                ),
              ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Provider.of<FirebaseFirestoreService>(context, listen: false).watchUserBookings(
          userId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                historyOnly
                    ? 'Không thể tải lịch sử đặt chỗ: ${snapshot.error}'
                    : 'Không thể tải danh sách vé: ${snapshot.error}',
              ),
            );
          }

          final data = snapshot.data ?? const [];
          final unusedBookings = <Map<String, dynamic>>[];
          final usedBookings = <Map<String, dynamic>>[];

          for (final booking in data) {
            if (_isUsedBooking(booking)) {
              usedBookings.add(booking);
            } else {
              unusedBookings.add(booking);
            }
          }

          final visibleBookings = historyOnly ? usedBookings : unusedBookings;
          if (visibleBookings.isEmpty) {
            return Center(
              child: Text(
                historyOnly
                    ? 'Bạn chưa có vé đã sử dụng.'
                    : 'Bạn chưa có vé chưa sử dụng.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: visibleBookings.length,
            separatorBuilder: (context, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final booking = visibleBookings[index];
              final movieTitle = _movieTitleFrom(booking);
              final theaterName = _theaterNameFrom(booking);
              final showtimeSummary = _showtimeSummaryFrom(
                booking,
                forceWeekdayDate: historyOnly,
              );

              return _TicketSummaryCard(
                movieTitle: movieTitle,
                theaterName: theaterName,
                showtimeSummary: showtimeSummary,
                isUsed: historyOnly,
                onTap: () => _showTicketDetailDialog(
                  context,
                  booking,
                  isUsed: historyOnly,
                ),
                onShareFeeling: historyOnly
                    ? () => _openReviewFromUsedBooking(context, booking)
                    : null,
              );
            },
          );
        },
      ),
      bottomNavigationBar: bottomNav,
    );
  }
}

class _TicketSummaryCard extends StatelessWidget {
  const _TicketSummaryCard({
    required this.movieTitle,
    required this.theaterName,
    required this.showtimeSummary,
    required this.isUsed,
    this.onTap,
    this.onShareFeeling,
  });

  final String movieTitle;
  final String theaterName;
  final String showtimeSummary;
  final bool isUsed;
  final VoidCallback? onTap;
  final VoidCallback? onShareFeeling;

  @override
  Widget build(BuildContext context) {
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          movieTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isUsed
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isUsed ? 'Đã sử dụng' : 'Chưa sử dụng',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isUsed
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Rạp: $theaterName'),
                  const SizedBox(height: 2),
                  Text('Giờ và ngày: $showtimeSummary'),
                  if (isUsed && onShareFeeling != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onShareFeeling,
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Chia sẻ cảm nhận'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}
