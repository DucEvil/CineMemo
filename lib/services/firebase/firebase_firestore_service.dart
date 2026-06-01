import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../models/review_model.dart';
import '../../utils/constants.dart';

class FirebaseFirestoreService {
  FirebaseFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore;

  FirebaseFirestore? _firestore;

  FirebaseFirestore? get _currentFirestore {
    final firestore = _firestore;
    if (firestore != null) {
      return firestore;
    }
    if (Firebase.apps.isEmpty) {
      return null;
    }
    _firestore = FirebaseFirestore.instance;
    return _firestore;
  }

  FirebaseFirestore get _requiredFirestore {
    final firestore = _currentFirestore;
    if (firestore == null) {
      throw StateError('FirebaseFirestore is not initialized.');
    }
    return firestore;
  }

  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _requiredFirestore.collection(path);
  }

  Future<void> upsertDocument({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return _requiredFirestore
        .collection(collectionPath)
        .doc(documentId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> upsertUserProfile({
    required String uid,
    required Map<String, dynamic> profile,
  }) async {
    final payload = {...profile, 'updatedAt': FieldValue.serverTimestamp()};
    await upsertDocument(
      collectionPath: AppConstants.usersCollection,
      documentId: uid,
      data: payload,
    );
  }

  Future<void> addUserFcmToken({
    required String uid,
    required String token,
  }) async {
    final normalizedUid = uid.trim();
    final normalizedToken = token.trim();
    if (normalizedUid.isEmpty || normalizedToken.isEmpty) {
      return;
    }

    await upsertDocument(
      collectionPath: AppConstants.usersCollection,
      documentId: normalizedUid,
      data: {
        'userId': normalizedUid,
        'fcmTokens': FieldValue.arrayUnion(<String>[normalizedToken]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> queueShowtimeReminder({
    required String reminderId,
    required String bookingId,
    required String userId,
    required String movieTitle,
    required String theaterName,
    required DateTime showStartAt,
    required DateTime scheduledFor,
    required List<String> targetTokens,
  }) async {
    final normalizedTokens = targetTokens
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedTokens.isEmpty) {
      throw StateError('Cannot queue reminder without FCM tokens.');
    }

    await upsertDocument(
      collectionPath: AppConstants.showtimeRemindersCollection,
      documentId: reminderId,
      data: {
        'bookingId': bookingId,
        'userId': userId,
        'movieTitle': movieTitle,
        'theaterName': theaterName,
        'title': 'Nhac lich xem phim',
        'body': '$movieTitle se chieu sau 30 phut tai $theaterName',
        'showStartAt': Timestamp.fromDate(showStartAt),
        'scheduledFor': Timestamp.fromDate(scheduledFor),
        'targetTokens': normalizedTokens,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final firestore = _currentFirestore;
    if (firestore == null) {
      return null;
    }

    final doc = await firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    return doc.data();
  }

  String _favoriteDocumentId({
    required String userId,
    required String movieId,
  }) {
    return '${userId.trim()}:${Uri.encodeComponent(movieId.trim())}';
  }

  Future<List<String>> getFavoriteMovieIds(String userId) async {
    final firestore = _currentFirestore;
    final normalizedUserId = userId.trim();

    if (firestore == null || normalizedUserId.isEmpty) {
      return const [];
    }

    final snapshot = await firestore
        .collection(AppConstants.favoritesCollection)
        .where('userId', isEqualTo: normalizedUserId)
        .get();

    return snapshot.docs
        .map((doc) => (doc.data()['movieId'] as String? ?? '').trim())
        .where((movieId) => movieId.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> upsertFavoriteMovie({
    required String userId,
    required String movieId,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedMovieId = movieId.trim();

    if (normalizedUserId.isEmpty || normalizedMovieId.isEmpty) {
      return;
    }

    final favoriteId = _favoriteDocumentId(
      userId: normalizedUserId,
      movieId: normalizedMovieId,
    );

    await upsertDocument(
      collectionPath: AppConstants.favoritesCollection,
      documentId: favoriteId,
      data: {
        'favoriteId': favoriteId,
        'userId': normalizedUserId,
        'movieId': normalizedMovieId,
        'listType': 'favorite',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> seedFavoriteMovies({
    required String userId,
    required List<String> movieIds,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }

    final normalizedMovieIds = movieIds
        .map((movieId) => movieId.trim())
        .where((movieId) => movieId.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedMovieIds.isEmpty) {
      return;
    }

    final firestore = _requiredFirestore;
    final favoritesCollection = firestore.collection(
      AppConstants.favoritesCollection,
    );
    final batch = firestore.batch();

    for (final movieId in normalizedMovieIds) {
      final favoriteId = _favoriteDocumentId(
        userId: normalizedUserId,
        movieId: movieId,
      );
      batch.set(favoritesCollection.doc(favoriteId), {
        'favoriteId': favoriteId,
        'userId': normalizedUserId,
        'movieId': movieId,
        'listType': 'favorite',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> deleteFavoriteMovie({
    required String userId,
    required String movieId,
  }) async {
    final firestore = _currentFirestore;
    final normalizedUserId = userId.trim();
    final normalizedMovieId = movieId.trim();

    if (firestore == null ||
        normalizedUserId.isEmpty ||
        normalizedMovieId.isEmpty) {
      return;
    }

    final favoriteId = _favoriteDocumentId(
      userId: normalizedUserId,
      movieId: normalizedMovieId,
    );

    await firestore
        .collection(AppConstants.favoritesCollection)
        .doc(favoriteId)
        .delete();
  }

  Future<void> createReservation({
    required String reservationId,
    required String userId,
    required String showtimeId,
    required List<String> seats,
    required DateTime expiresAt,
  }) async {
    final normalizedShowtimeId = showtimeId.trim();
    final normalizedSeats = [...seats]..sort();

    await upsertDocument(
      collectionPath: AppConstants.reservationsCollection,
      documentId: reservationId,
      data: {
        'reservationId': reservationId,
        'userId': userId,
        'showtimeId': normalizedShowtimeId,
        'seats': normalizedSeats,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await upsertDocument(
      collectionPath:
          '${AppConstants.showtimeSeatStatesCollection}/$normalizedShowtimeId/${AppConstants.showtimeSeatReservationsSubcollection}',
      documentId: reservationId,
      data: {
        'reservationId': reservationId,
        'showtimeId': normalizedShowtimeId,
        'userId': userId,
        'seats': normalizedSeats,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteReservation(String reservationId) async {
    final firestore = _requiredFirestore;
    final reservationRef = firestore
        .collection(AppConstants.reservationsCollection)
        .doc(reservationId);

    String showtimeId = '';
    final reservationSnapshot = await reservationRef.get();
    if (reservationSnapshot.exists) {
      showtimeId = (reservationSnapshot.data()?['showtimeId'] as String? ?? '')
          .trim();
    }

    final batch = firestore.batch();
    batch.delete(reservationRef);

    if (showtimeId.isNotEmpty) {
      final seatStateReservationRef = firestore
          .collection(AppConstants.showtimeSeatStatesCollection)
          .doc(showtimeId)
          .collection(AppConstants.showtimeSeatReservationsSubcollection)
          .doc(reservationId);
      batch.delete(seatStateReservationRef);
    }

    await batch.commit();
  }

  Future<void> createBooking({
    required String bookingId,
    required String userId,
    required String showtimeId,
    required List<String> seats,
    required double totalPrice,
    required String qrPayload,
    Map<String, dynamic> extraData = const {},
  }) async {
    final normalizedShowtimeId = showtimeId.trim();
    final normalizedSeats = [...seats]..sort();

    await upsertDocument(
      collectionPath: AppConstants.bookingsCollection,
      documentId: bookingId,
      data: {
        'bookingId': bookingId,
        'userId': userId,
        'showtimeId': normalizedShowtimeId,
        'seats': normalizedSeats,
        'totalPrice': totalPrice,
        'status': 'paid',
        'qrPayload': qrPayload,
        'createdAt': FieldValue.serverTimestamp(),
        'transactionAt': FieldValue.serverTimestamp(),
        ...extraData,
      },
    );

    await upsertDocument(
      collectionPath:
          '${AppConstants.showtimeSeatStatesCollection}/$normalizedShowtimeId/${AppConstants.showtimeSeatBookingsSubcollection}',
      documentId: bookingId,
      data: {
        'bookingId': bookingId,
        'showtimeId': normalizedShowtimeId,
        'userId': userId,
        'seats': normalizedSeats,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> createReview(ReviewModel review) async {
    final reviewId = review.reviewId.trim();
    if (reviewId.isEmpty) {
      throw ArgumentError('reviewId must not be empty.');
    }

    final payload = <String, dynamic>{
      'reviewId': reviewId,
      'userId': review.userId.trim(),
      'userDisplayName': review.userDisplayName.trim(),
      'userPhotoUrl': review.userPhotoUrl?.trim(),
      'movieId': review.movieId.trim(),
      'movieTitle': review.movieTitle.trim(),
      'rating': review.rating.clamp(0, 5).toDouble(),
      'content': review.content.trim(),
      'weather': review.weather?.trim(),
      'location': review.location?.trim(),
      'imageUrl': review.imageUrl?.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }..removeWhere((key, value) => value == null);

    await upsertDocument(
      collectionPath: AppConstants.reviewsCollection,
      documentId: reviewId,
      data: payload,
    );
  }

  Future<void> updateReview({
    required String reviewId,
    required String content,
    required double rating,
    String? weather,
    String? location,
    String? imageUrl,
  }) async {
    final normalizedReviewId = reviewId.trim();
    if (normalizedReviewId.isEmpty) {
      throw ArgumentError('reviewId must not be empty.');
    }

    final payload = <String, dynamic>{
      'content': content.trim(),
      'rating': rating.clamp(0, 5).toDouble(),
      'weather': weather?.trim(),
      'location': location?.trim(),
      'imageUrl': imageUrl?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }..removeWhere((key, value) => value == null);

    await _requiredFirestore
        .collection(AppConstants.reviewsCollection)
        .doc(normalizedReviewId)
        .update(payload);
  }

  Future<void> deleteReview(String reviewId) async {
    final normalizedReviewId = reviewId.trim();
    if (normalizedReviewId.isEmpty) {
      return;
    }

    await _requiredFirestore
        .collection(AppConstants.reviewsCollection)
        .doc(normalizedReviewId)
        .delete();
  }

  Stream<List<ReviewModel>> watchReviews({int limit = 120}) {
    final firestore = _currentFirestore;
    if (firestore == null) {
      return Stream<List<ReviewModel>>.value(const <ReviewModel>[]);
    }

    return firestore
        .collection(AppConstants.reviewsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapReviewSnapshot);
  }

  Stream<List<ReviewModel>> watchUserReviews(String userId, {int limit = 120}) {
    final firestore = _currentFirestore;
    final normalizedUserId = userId.trim();

    if (firestore == null || normalizedUserId.isEmpty) {
      return Stream<List<ReviewModel>>.value(const <ReviewModel>[]);
    }

    return firestore
        .collection(AppConstants.reviewsCollection)
        .where('userId', isEqualTo: normalizedUserId)
        .snapshots()
        .map((snapshot) {
          final reviews = _mapReviewSnapshot(snapshot);
          if (reviews.length <= limit) {
            return reviews;
          }
          return reviews.sublist(0, limit);
        });
  }

  Stream<List<ReviewModel>> watchMovieReviews(
    String movieId, {
    int limit = 80,
  }) {
    final firestore = _currentFirestore;
    final normalizedMovieId = movieId.trim();

    if (firestore == null || normalizedMovieId.isEmpty) {
      return Stream<List<ReviewModel>>.value(const <ReviewModel>[]);
    }

    return firestore
        .collection(AppConstants.reviewsCollection)
        .where('movieId', isEqualTo: normalizedMovieId)
        .snapshots()
        .map((snapshot) {
          final reviews = _mapReviewSnapshot(snapshot);
          if (reviews.length <= limit) {
            return reviews;
          }
          return reviews.sublist(0, limit);
        });
  }

  List<ReviewModel> _mapReviewSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final reviews = snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['reviewId'] = (data['reviewId'] as String? ?? doc.id).trim();
      data['createdAt'] = _toDateTime(data['createdAt']);
      data['updatedAt'] = _toDateTime(data['updatedAt']);
      return ReviewModel.fromMap(data);
    }).toList();

    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return reviews;
  }

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

  Stream<Set<String>> watchShowtimeBookedSeats(String showtimeId) {
    final firestore = _currentFirestore;
    final normalizedShowtimeId = showtimeId.trim();

    if (firestore == null || normalizedShowtimeId.isEmpty) {
      return Stream<Set<String>>.value(<String>{});
    }

    return firestore
        .collection(AppConstants.showtimeSeatStatesCollection)
        .doc(normalizedShowtimeId)
        .collection(AppConstants.showtimeSeatBookingsSubcollection)
        .snapshots()
        .map((snapshot) {
          final bookedSeats = <String>{};

          for (final doc in snapshot.docs) {
            final seatsRaw = doc.data()['seats'];
            if (seatsRaw is! List) {
              continue;
            }

            for (final seat in seatsRaw.whereType<String>()) {
              final normalizedSeat = seat.trim();
              if (normalizedSeat.isNotEmpty) {
                bookedSeats.add(normalizedSeat);
              }
            }
          }

          return bookedSeats;
        });
  }

  Stream<Set<String>> watchShowtimeHeldSeats(String showtimeId) {
    final firestore = _currentFirestore;
    final normalizedShowtimeId = showtimeId.trim();

    if (firestore == null || normalizedShowtimeId.isEmpty) {
      return Stream<Set<String>>.value(<String>{});
    }

    return firestore
        .collection(AppConstants.showtimeSeatStatesCollection)
        .doc(normalizedShowtimeId)
        .collection(AppConstants.showtimeSeatReservationsSubcollection)
        .snapshots()
        .map((snapshot) {
          final heldSeats = <String>{};
          final now = DateTime.now();

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final expiresAtRaw = data['expiresAt'];
            final expiresAt = expiresAtRaw is Timestamp
                ? expiresAtRaw.toDate()
                : null;

            if (expiresAt == null || !expiresAt.isAfter(now)) {
              continue;
            }

            final seatsRaw = data['seats'];
            if (seatsRaw is! List) {
              continue;
            }

            for (final seat in seatsRaw.whereType<String>()) {
              final normalizedSeat = seat.trim();
              if (normalizedSeat.isNotEmpty) {
                heldSeats.add(normalizedSeat);
              }
            }
          }

          return heldSeats;
        });
  }

  Stream<List<Map<String, dynamic>>> watchUserBookings(String userId) {
    final firestore = _currentFirestore;
    if (firestore == null) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }

    return firestore
        .collection(AppConstants.bookingsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();

          bookings.sort((a, b) {
            final aTs = a['createdAt'];
            final bTs = b['createdAt'];
            final aDate = aTs is Timestamp ? aTs.toDate() : null;
            final bDate = bTs is Timestamp ? bTs.toDate() : null;

            if (aDate == null && bDate == null) {
              return 0;
            }
            if (aDate == null) {
              return 1;
            }
            if (bDate == null) {
              return -1;
            }
            return bDate.compareTo(aDate);
          });

          return bookings;
        });
  }
}
