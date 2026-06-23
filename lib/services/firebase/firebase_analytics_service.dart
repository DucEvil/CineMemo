import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseAnalyticsService {
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      // Platform-specific method, may fail on some platforms
      if (kDebugMode) print('Analytics error (logAppOpen): $e');
    }
  }

  Future<void> logScreenView({required String screenName}) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      if (kDebugMode) print('Analytics error (logScreenView): $e');
    }
  }

  Future<void> logSearch({required String searchTerm}) async {
    try {
      await _analytics.logEvent(
        name: 'search',
        parameters: {'search_term': searchTerm},
      );
    } catch (e) {
      if (kDebugMode) print('Analytics error (logSearch): $e');
    }
  }

  Future<void> logMovieViewed({
    required String movieId,
    String? movieTitle,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'movie_viewed',
        parameters: {
          'movie_id': movieId,
          if (movieTitle != null && movieTitle.isNotEmpty)
            'movie_title': movieTitle,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Analytics error (logMovieViewed): $e');
    }
  }

  Future<void> logBookingComplete({
    required String bookingId,
    required String showtimeId,
    required int ticketCount,
    required double totalPrice,
    String? movieTitle,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'booking_complete',
        parameters: {
          'booking_id': bookingId,
          'showtime_id': showtimeId,
          'ticket_count': ticketCount,
          'total_price': totalPrice,
          if (movieTitle != null && movieTitle.isNotEmpty)
            'movie_title': movieTitle,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Analytics error (logBookingComplete): $e');
    }
  }

  Future<void> logAccountCreated({
    required String method,
    String? emailDomain,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'account_created',
        parameters: {
          'method': method,
          if (emailDomain != null && emailDomain.isNotEmpty)
            'email_domain': emailDomain,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Analytics error (logAccountCreated): $e');
    }
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      if (kDebugMode) print('Analytics error (logEvent): $e');
    }
  }
}
