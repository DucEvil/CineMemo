import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/review_model.dart';
import '../services/firebase/firebase_firestore_service.dart';
import '../utils/constants.dart';

class ReviewProvider extends ChangeNotifier {
  ReviewProvider({required FirebaseFirestoreService firestoreService})
    : _firestoreService = firestoreService;

  final FirebaseFirestoreService _firestoreService;

  int _reviewCount = 0;
  bool _syncing = false;
  String? _activeUserId;
  StreamSubscription<List<ReviewModel>>? _myReviewsSubscription;

  int get reviewCount => _reviewCount;
  bool get syncing => _syncing;
  String? get activeUserId => _activeUserId;

  void setReviewCount(int value) {
    _reviewCount = value;
    notifyListeners();
  }

  void bindUser(String? userId) {
    final normalized = (userId ?? '').trim();
    final nextUserId = normalized.isEmpty ? null : normalized;

    if (_activeUserId == nextUserId) {
      return;
    }

    _activeUserId = nextUserId;
    _myReviewsSubscription?.cancel();

    if (nextUserId == null) {
      _reviewCount = 0;
      _syncing = false;
      notifyListeners();
      return;
    }

    _syncing = true;
    notifyListeners();

    _myReviewsSubscription = _firestoreService
        .watchUserReviews(nextUserId)
        .listen(
          (reviews) {
            _reviewCount = reviews.length;
            _syncing = false;
            notifyListeners();
          },
          onError: (_) {
            _syncing = false;
            notifyListeners();
          },
        );
  }

  Future<void> refreshCurrentUserReviewCount() async {
    final userId = _activeUserId;
    if (userId == null) {
      _reviewCount = 0;
      notifyListeners();
      return;
    }

    _syncing = true;
    notifyListeners();

    try {
      final snapshot = await _firestoreService
          .collection(AppConstants.reviewsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      _reviewCount = snapshot.docs.length;
    } catch (_) {
      // Keep latest known count when network is unstable.
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _myReviewsSubscription?.cancel();
    super.dispose();
  }
}
