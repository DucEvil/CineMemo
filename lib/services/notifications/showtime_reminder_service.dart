import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../utils/constants.dart';
import '../firebase/firebase_firestore_service.dart';

class ShowtimeReminderResult {
  const ShowtimeReminderResult({
    required this.attempted,
    required this.success,
    this.message,
  });

  final bool attempted;
  final bool success;
  final String? message;

  static const skipped = ShowtimeReminderResult(
    attempted: false,
    success: false,
  );
}

class ShowtimeReminderService {
  ShowtimeReminderService({
    required FirebaseFirestoreService firestoreService,
    FirebaseMessaging? messaging,
  }) : _firestoreService = firestoreService,
       _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseFirestoreService _firestoreService;
  final FirebaseMessaging _messaging;
  bool _initialized = false;
  bool _notificationsEnabled = true;

  Future<void> _initializeIfNeeded() async {
    if (_initialized || kIsWeb) {
      return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _notificationsEnabled =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    _initialized = true;
  }

  Future<ShowtimeReminderResult> scheduleReminder({
    required String bookingId,
    required String userId,
    required String movieTitle,
    required String theaterName,
    required DateTime showStartAt,
  }) async {
    if (kIsWeb) {
      return const ShowtimeReminderResult(
        attempted: false,
        success: false,
        message: '',
      );
    }

    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return const ShowtimeReminderResult(
        attempted: false,
        success: false,
        message: 'Khong xac dinh duoc nguoi dung nhan thong bao.',
      );
    }

    await _initializeIfNeeded();

    if (!_notificationsEnabled) {
      return const ShowtimeReminderResult(
        attempted: false,
        success: false,
        message: 'Thong bao dang tat. Vui long bat thong bao cho ung dung.',
      );
    }

    final remindAt = showStartAt.subtract(
      const Duration(minutes: AppConstants.showtimeReminderLeadMinutes),
    );
    final now = DateTime.now();
    if (!remindAt.isAfter(now)) {
      return const ShowtimeReminderResult(
        attempted: false,
        success: false,
        message: 'Suat chieu qua gan gio, khong the hen nhac truoc 30 phut.',
      );
    }

    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        return const ShowtimeReminderResult(
          attempted: true,
          success: false,
          message: 'Khong lay duoc FCM token de hen nhac thong bao.',
        );
      }

      final normalizedToken = token.trim();
      await _firestoreService.addUserFcmToken(
        uid: normalizedUserId,
        token: normalizedToken,
      );

      final profile = await _firestoreService.getUserProfile(normalizedUserId);
      final storedTokensRaw = profile?['fcmTokens'];
      final knownTokens = <String>{normalizedToken};
      if (storedTokensRaw is List) {
        for (final rawToken in storedTokensRaw.whereType<String>()) {
          final trimmedToken = rawToken.trim();
          if (trimmedToken.isNotEmpty) {
            knownTokens.add(trimmedToken);
          }
        }
      }

      await _firestoreService.queueShowtimeReminder(
        reminderId: bookingId,
        bookingId: bookingId,
        userId: normalizedUserId,
        movieTitle: movieTitle,
        theaterName: theaterName,
        showStartAt: showStartAt,
        scheduledFor: remindAt,
        targetTokens: knownTokens.toList(),
      );

      return const ShowtimeReminderResult(
        attempted: true,
        success: true,
        message: 'Da tao lich nhac FCM 30 phut truoc gio chieu.',
      );
    } catch (_) {
      return const ShowtimeReminderResult(
        attempted: true,
        success: false,
        message: 'Khong the tao lich nhac FCM cho lich chieu.',
      );
    }
  }
}
