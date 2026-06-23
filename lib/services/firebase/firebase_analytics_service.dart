import 'package:firebase_analytics/firebase_analytics.dart';

class FirebaseAnalyticsService {
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  Future<void> logScreenView({required String screenName}) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  Future<void> logSearch({required String searchTerm}) async {
    await _analytics.logEvent(
      name: 'search',
      parameters: {'search_term': searchTerm},
    );
  }

  Future<void> logMovieViewed({
    required String movieId,
    String? movieTitle,
  }) async {
    await _analytics.logEvent(
      name: 'movie_viewed',
      parameters: {
        'movie_id': movieId,
        if (movieTitle != null && movieTitle.isNotEmpty)
          'movie_title': movieTitle,
      },
    );
  }

  Future<void> logBookingComplete({
    required String bookingId,
    required String showtimeId,
    required int ticketCount,
    required double totalPrice,
    String? movieTitle,
  }) async {
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
  }

  Future<void> logAccountCreated({
    required String method,
    String? emailDomain,
  }) async {
    await _analytics.logEvent(
      name: 'account_created',
      parameters: {
        'method': method,
        if (emailDomain != null && emailDomain.isNotEmpty)
          'email_domain': emailDomain,
      },
    );
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }
}
