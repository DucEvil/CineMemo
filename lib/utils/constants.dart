class AppConstants {
  static const String appName = 'CineMemo';
  static const int reservationTimeoutMinutes = 15;
  static const int showtimeReminderLeadMinutes = 30;
  static const String usersCollection = 'users';
  static const String moviesCollection = 'movies';
  static const String theatersCollection = 'theaters';
  static const String showtimesCollection = 'showtimes';
  static const String bookingsCollection = 'bookings';
  static const String showtimeRemindersCollection = 'showtimeReminders';
  static const String showtimeSeatStatesCollection = 'showtimeSeatStates';
  static const String showtimeSeatBookingsSubcollection = 'bookings';
  static const String showtimeSeatReservationsSubcollection = 'reservations';
  static const String reviewsCollection = 'reviews';
  static const String favoritesCollection = 'favorites';
  static const String reservationsCollection = 'reservations';
  static const String transactionsCollection = 'transactions';
  static const String logsCollection = 'logs';
  static const String bannersCollection = 'banners';
  // The Firebase Extension is configured to use the `generate` collection.
  // Create requests in `generate` so the extension processes them and writes
  // the `response` field on the same document.
  static const String aiRequestsCollection = 'generate';
  static const String aiGenerateCollection = 'generate';
}
