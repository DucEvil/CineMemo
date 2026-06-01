import '../../utils/constants.dart';
import 'firebase_firestore_service.dart';

class FirebaseStorageService {
  FirebaseStorageService({FirebaseFirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirebaseFirestoreService();

  final FirebaseFirestoreService _firestoreService;

  Future<void> saveBookingImage({
    required String bookingId,
    required String imageUrl,
  }) {
    return _firestoreService.upsertDocument(
      collectionPath: AppConstants.bookingsCollection,
      documentId: bookingId,
      data: {'ticketImageUrl': imageUrl},
    );
  }

  Future<void> saveReviewImage({
    required String reviewId,
    required String imageUrl,
  }) {
    return _firestoreService.upsertDocument(
      collectionPath: AppConstants.reviewsCollection,
      documentId: reviewId,
      data: {'imageUrl': imageUrl},
    );
  }
}
