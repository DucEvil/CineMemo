import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../services/integrations/google_calendar_service.dart';
import '../services/integrations/ticket_email_service.dart';
import '../services/firebase/firebase_analytics_service.dart';
import '../services/firebase/firebase_firestore_service.dart';
import '../services/notifications/showtime_reminder_service.dart';
import '../services/payment/momo_payment_service.dart';
import '../services/utils/qr_helper.dart';
import '../utils/constants.dart';

class BookingProvider extends ChangeNotifier {
  BookingProvider({
    required FirebaseFirestoreService firestoreService,
    required MomoPaymentService momoPaymentService,
    required GoogleCalendarService googleCalendarService,
    required TicketEmailService ticketEmailService,
    required ShowtimeReminderService showtimeReminderService,
    required FirebaseAnalyticsService analyticsService,
  }) : _firestoreService = firestoreService,
       _momoPaymentService = momoPaymentService,
       _googleCalendarService = googleCalendarService,
       _ticketEmailService = ticketEmailService,
       _showtimeReminderService = showtimeReminderService,
       _analyticsService = analyticsService;

  final FirebaseFirestoreService _firestoreService;
  final MomoPaymentService _momoPaymentService;
  final GoogleCalendarService _googleCalendarService;
  final TicketEmailService _ticketEmailService;
  final ShowtimeReminderService _showtimeReminderService;
  final FirebaseAnalyticsService _analyticsService;

  bool _processingPayment = false;
  String? _error;
  String? _lastBookingId;
  String? _lastQrPayload;
  bool _calendarSynced = false;
  String? _calendarSyncMessage;
  bool _ticketEmailSent = false;
  String? _ticketEmailMessage;
  bool _showtimeReminderScheduled = false;
  String? _showtimeReminderMessage;
  final Set<String> _selectedSeats = <String>{};
  String? _seatSessionUserId;
  String? _seatSessionShowtimeId;
  String? _activeReservationId;
  DateTime? _reservationExpiresAt;
  String? _seatSelectionNotice;
  Timer? _reservationCountdownTimer;
  Future<void> _reservationSyncQueue = Future<void>.value();

  bool get processingPayment => _processingPayment;
  String? get error => _error;
  String? get lastBookingId => _lastBookingId;
  String? get lastQrPayload => _lastQrPayload;
  bool get calendarSynced => _calendarSynced;
  String? get calendarSyncMessage => _calendarSyncMessage;
  bool get ticketEmailSent => _ticketEmailSent;
  String? get ticketEmailMessage => _ticketEmailMessage;
  bool get showtimeReminderScheduled => _showtimeReminderScheduled;
  String? get showtimeReminderMessage => _showtimeReminderMessage;
  Set<String> get selectedSeats => _selectedSeats;
  String? get seatSelectionNotice => _seatSelectionNotice;
  DateTime? get reservationExpiresAt => _reservationExpiresAt;
  bool get hasActiveSeatReservation =>
      _activeReservationId != null && _selectedSeats.isNotEmpty;

  Duration get reservationRemaining {
    final expiresAt = _reservationExpiresAt;
    if (expiresAt == null) {
      return Duration.zero;
    }
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) {
      return Duration.zero;
    }
    return diff;
  }

  String get reservationCountdownLabel {
    final remaining = reservationRemaining;
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void setProcessingPayment(bool value) {
    _processingPayment = value;
    notifyListeners();
  }

  void toggleSeat(String seatCode) {
    _seatSelectionNotice = null;
    if (_selectedSeats.contains(seatCode)) {
      _selectedSeats.remove(seatCode);
    } else {
      _selectedSeats.add(seatCode);
    }
    notifyListeners();
    _queueReservationSync();
  }

  void clearSeatSelection() {
    _selectedSeats.clear();
    _seatSelectionNotice = null;
    notifyListeners();
    _queueReservationSync();
  }

  void startSeatSelectionSession({
    required String userId,
    required String showtimeId,
  }) {
    final normalizedUserId = userId.trim().isEmpty
        ? 'guest-user'
        : userId.trim();
    final normalizedShowtimeId = showtimeId.trim();

    if (_seatSessionUserId == normalizedUserId &&
        _seatSessionShowtimeId == normalizedShowtimeId) {
      return;
    }

    final previousReservationId = _activeReservationId;
    _seatSessionUserId = normalizedUserId;
    _seatSessionShowtimeId = normalizedShowtimeId;
    _activeReservationId = null;
    _reservationExpiresAt = null;
    _seatSelectionNotice = null;
    _selectedSeats.clear();
    _stopReservationCountdown();
    notifyListeners();

    if (previousReservationId != null) {
      unawaited(_safeDeleteReservation(previousReservationId));
    }
  }

  Future<void> cancelSeatSelectionSession() async {
    final previousReservationId = _activeReservationId;
    _activeReservationId = null;
    _reservationExpiresAt = null;
    _seatSessionShowtimeId = null;
    _seatSessionUserId = null;
    _seatSelectionNotice = null;
    _selectedSeats.clear();
    _stopReservationCountdown();
    notifyListeners();

    if (previousReservationId != null) {
      await _safeDeleteReservation(previousReservationId);
    }
  }

  String _buildTicketCode(String bookingId) {
    final normalized = bookingId.replaceAll('-', '').toUpperCase();
    final suffix = normalized.length >= 8
        ? normalized.substring(0, 8)
        : normalized.padRight(8, '0');
    return 'VE-$suffix';
  }

  String _buildTransactionId() {
    return 'GD-${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic> _normalizeBookingDetails(
    Map<String, dynamic>? bookingDetails,
  ) {
    if (bookingDetails == null) {
      return <String, dynamic>{};
    }

    final normalized = Map<String, dynamic>.from(bookingDetails);
    normalized.removeWhere((key, value) => value == null);
    return normalized;
  }

  void _queueReservationSync() {
    _reservationSyncQueue = _reservationSyncQueue
        .then((_) => _syncReservationForSelection())
        .catchError((_) {});
  }

  Future<void> _syncReservationForSelection() async {
    final showtimeId = _seatSessionShowtimeId;
    final userId = _seatSessionUserId;
    if (showtimeId == null || showtimeId.isEmpty || userId == null) {
      return;
    }

    if (_selectedSeats.isEmpty) {
      await _releaseActiveReservation(clearSeats: false, clearSession: false);
      return;
    }

    final now = DateTime.now();
    final currentExpiresAt = _reservationExpiresAt;
    if (currentExpiresAt != null && !currentExpiresAt.isAfter(now)) {
      await _expireSeatSelection();
      return;
    }

    final reservationId = _activeReservationId ?? const Uuid().v4();
    final expiresAt =
        _reservationExpiresAt ??
        now.add(
          const Duration(minutes: AppConstants.reservationTimeoutMinutes),
        );

    _activeReservationId = reservationId;
    _reservationExpiresAt = expiresAt;
    _startReservationCountdown();
    notifyListeners();

    try {
      await _firestoreService.createReservation(
        reservationId: reservationId,
        userId: userId,
        showtimeId: showtimeId,
        seats: _selectedSeats.toList(),
        expiresAt: expiresAt,
      );
    } catch (_) {
      // Keep local session running; backend sync can recover on next seat change.
    }
  }

  void _startReservationCountdown() {
    _reservationCountdownTimer?.cancel();
    _reservationCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      _,
    ) {
      final expiresAt = _reservationExpiresAt;
      if (expiresAt == null) {
        _stopReservationCountdown();
        return;
      }

      if (!expiresAt.isAfter(DateTime.now())) {
        unawaited(_expireSeatSelection());
        return;
      }

      notifyListeners();
    });
  }

  void _stopReservationCountdown() {
    _reservationCountdownTimer?.cancel();
    _reservationCountdownTimer = null;
  }

  Future<void> _expireSeatSelection() async {
    _seatSelectionNotice = 'Het 15 phut giu ghe, vui long chon lai.';
    await _releaseActiveReservation(clearSeats: true, clearSession: false);
  }

  Future<void> _releaseActiveReservation({
    required bool clearSeats,
    required bool clearSession,
  }) async {
    final previousReservationId = _activeReservationId;
    _activeReservationId = null;
    _reservationExpiresAt = null;
    if (clearSeats) {
      _selectedSeats.clear();
    }
    if (clearSession) {
      _seatSessionShowtimeId = null;
      _seatSessionUserId = null;
    }
    _stopReservationCountdown();
    notifyListeners();

    if (previousReservationId != null) {
      await _safeDeleteReservation(previousReservationId);
    }
  }

  Future<void> _safeDeleteReservation(String reservationId) async {
    try {
      await _firestoreService.deleteReservation(reservationId);
    } catch (_) {
      // Ignore cleanup failures to keep booking flow smooth.
    }
  }

  DateTime? _showStartAtFrom(String showtimeId, Map<String, dynamic> details) {
    final raw = details['showStartAt'] ?? details['showtimeStartAt'];
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(raw.trim());
      if (parsed != null) {
        return parsed;
      }
    }

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

  Future<void> _syncBookingToCalendar({
    required String bookingId,
    required String ticketCode,
    required String showtimeId,
    required double totalPrice,
    required Map<String, dynamic> details,
  }) async {
    _calendarSynced = false;
    _calendarSyncMessage = null;

    final movieTitle = (details['movieTitle'] as String? ?? 'Phim').trim();
    final theaterName = (details['theaterName'] as String? ?? '').trim();
    final theaterAddress = (details['theaterAddress'] as String? ?? '').trim();
    final showtimeLabel = (details['showtimeLabel'] as String? ?? '').trim();
    final seats = _selectedSeats.toList()..sort();
    final durationMinutes = ((details['movieDuration'] as num?)?.toInt() ?? 150)
        .clamp(30, 360)
        .toInt();

    final startAt = _showStartAtFrom(showtimeId, details);
    if (startAt == null) {
      _calendarSyncMessage =
          'Khong xac dinh duoc gio chieu de dong bo Google Calendar.';
      return;
    }

    final location = [
      theaterName,
      theaterAddress,
    ].where((part) => part.trim().isNotEmpty).join(' - ');
    final descriptionBuffer = StringBuffer()
      ..writeln('Dat ve thanh cong tren CineMemo')
      ..writeln('Ma dat ve: $bookingId')
      ..writeln('Ma ve: $ticketCode')
      ..writeln('Suat chieu: $showtimeLabel')
      ..writeln('Ghe: ${seats.isEmpty ? 'Chua xac dinh' : seats.join(', ')}')
      ..writeln('Tong tien: ${totalPrice.round()} VND');

    final result = await _googleCalendarService.createBookingEvent(
      summary: 'Xem phim: $movieTitle',
      description: descriptionBuffer.toString().trim(),
      location: location,
      startAt: startAt,
      endAt: startAt.add(Duration(minutes: durationMinutes)),
    );

    if (!result.attempted) {
      return;
    }

    _calendarSynced = result.success;
    _calendarSyncMessage = result.message;
  }

  Future<void> _sendTicketEmail({
    required String bookingId,
    required String ticketCode,
    required String qrPayload,
    required String showtimeId,
    required double totalPrice,
    required Map<String, dynamic> details,
  }) async {
    _ticketEmailSent = false;
    _ticketEmailMessage = null;

    final isGoogleAccount = details['isGoogleAccount'] == true;
    if (!isGoogleAccount) {
      return;
    }

    final userEmail = (details['userEmail'] as String? ?? '').trim();
    final movieTitle = (details['movieTitle'] as String? ?? 'Phim').trim();
    final theaterName = (details['theaterName'] as String? ?? '').trim();
    final showtimeLabel = (details['showtimeLabel'] as String? ?? '').trim();
    final seats = _selectedSeats.toList()..sort();
    final showStartAt = _showStartAtFrom(showtimeId, details);

    final result = await _ticketEmailService.sendTicketEmail(
      recipientEmail: userEmail,
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

    if (!result.attempted &&
        (result.message == null || result.message!.trim().isEmpty)) {
      return;
    }

    _ticketEmailSent = result.success;
    _ticketEmailMessage = result.message;
  }

  Future<void> _scheduleShowtimeReminder({
    required String userId,
    required String bookingId,
    required String showtimeId,
    required Map<String, dynamic> details,
  }) async {
    _showtimeReminderScheduled = false;
    _showtimeReminderMessage = null;

    final showStartAt = _showStartAtFrom(showtimeId, details);
    if (showStartAt == null) {
      _showtimeReminderMessage =
          'Khong xac dinh duoc gio chieu de hen nhac thong bao.';
      return;
    }

    final movieTitle = (details['movieTitle'] as String? ?? 'Phim').trim();
    final theaterName = (details['theaterName'] as String? ?? '').trim();

    final result = await _showtimeReminderService.scheduleReminder(
      bookingId: bookingId,
      userId: userId,
      movieTitle: movieTitle,
      theaterName: theaterName,
      showStartAt: showStartAt,
    );

    if (!result.attempted &&
        (result.message == null || result.message!.trim().isEmpty)) {
      return;
    }

    _showtimeReminderScheduled = result.success;
    _showtimeReminderMessage = result.message;
  }

  Future<bool> checkout({
    required String userId,
    required String showtimeId,
    required double totalPrice,
    Map<String, dynamic>? bookingDetails,
    bool skipPaymentGateway = false,
  }) async {
    if (_selectedSeats.isEmpty) {
      _error = 'Please choose at least one seat.';
      notifyListeners();
      return false;
    }

    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty || normalizedUserId == 'guest-user') {
      _error = 'Vui long dang nhap lai de tiep tuc dat ve.';
      notifyListeners();
      return false;
    }

    _processingPayment = true;
    _error = null;
    _calendarSynced = false;
    _calendarSyncMessage = null;
    _ticketEmailSent = false;
    _ticketEmailMessage = null;
    _showtimeReminderScheduled = false;
    _showtimeReminderMessage = null;
    notifyListeners();

    try {
      const uuid = Uuid();
      final reservationId = _activeReservationId ?? uuid.v4();
      final reservationExpiresAt =
          _reservationExpiresAt ??
          DateTime.now().add(
            const Duration(minutes: AppConstants.reservationTimeoutMinutes),
          );
      final bookingId = uuid.v4();

      await _firestoreService.createReservation(
        reservationId: reservationId,
        userId: normalizedUserId,
        showtimeId: showtimeId,
        seats: _selectedSeats.toList(),
        expiresAt: reservationExpiresAt,
      );

      _activeReservationId = reservationId;
      _reservationExpiresAt = reservationExpiresAt;

      if (!skipPaymentGateway) {
        final paymentResult = await _momoPaymentService.pay(
          MomoPaymentRequest(
            orderId: bookingId,
            amount: totalPrice,
            description: 'CineMemo booking payment',
          ),
        );

        if (paymentResult.status != MomoPaymentStatus.success) {
          _error = paymentResult.message ?? 'Payment was not successful.';
          return false;
        }
      }

      final qrPayload = QrHelper.buildTicketPayload(
        bookingId: bookingId,
        showtimeId: showtimeId,
        userId: normalizedUserId,
      );

      final ticketCode = _buildTicketCode(bookingId);
      final transactionId = _buildTransactionId();
      final normalizedDetails = _normalizeBookingDetails(bookingDetails);

      await _firestoreService.createBooking(
        bookingId: bookingId,
        userId: normalizedUserId,
        showtimeId: showtimeId,
        seats: _selectedSeats.toList(),
        totalPrice: totalPrice,
        qrPayload: qrPayload,
        extraData: {
          'ticketCode': ticketCode,
          'transactionId': transactionId,
          'ticketCount': _selectedSeats.length,
          ...normalizedDetails,
        },
      );

      await _syncBookingToCalendar(
        bookingId: bookingId,
        ticketCode: ticketCode,
        showtimeId: showtimeId,
        totalPrice: totalPrice,
        details: normalizedDetails,
      );

      await _sendTicketEmail(
        bookingId: bookingId,
        ticketCode: ticketCode,
        qrPayload: qrPayload,
        showtimeId: showtimeId,
        totalPrice: totalPrice,
        details: normalizedDetails,
      );

      await _scheduleShowtimeReminder(
        userId: normalizedUserId,
        bookingId: bookingId,
        showtimeId: showtimeId,
        details: normalizedDetails,
      );

      _lastBookingId = bookingId;
      _lastQrPayload = qrPayload;

      await _releaseActiveReservation(clearSeats: true, clearSession: true);

      final movieTitle = normalizedDetails['movieTitle'] as String?;
      final ticketCount = _selectedSeats.isNotEmpty
          ? _selectedSeats.length
          : (normalizedDetails['ticketCount'] as int? ?? 0);

      unawaited(
        _analyticsService.logBookingComplete(
          bookingId: bookingId,
          showtimeId: showtimeId,
          ticketCount: ticketCount,
          totalPrice: totalPrice,
          movieTitle: movieTitle,
        ),
      );

      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _processingPayment = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopReservationCountdown();
    super.dispose();
  }
}
