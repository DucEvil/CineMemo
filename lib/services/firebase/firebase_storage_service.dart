import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/constants.dart';
import 'firebase_firestore_service.dart';

class FirebaseStorageService {
  FirebaseStorageService({FirebaseFirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirebaseFirestoreService();

  final FirebaseFirestoreService _firestoreService;

  FirebaseStorage get _storage {
    if (Firebase.apps.isEmpty) {
      throw StateError('FirebaseStorage is not initialized.');
    }
    return FirebaseStorage.instance;
  }

  Future<String?> uploadFile({
    required String folder,
    required XFile file,
    String? ownerUid,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return null;
    }

    final fileName = file.name.trim().isEmpty
        ? 'file_${DateTime.now().millisecondsSinceEpoch}'
        : file.name.trim().replaceAll(RegExp(r'\s+'), '_');
    final storagePath = '$folder/$fileName';
    final metadata = SettableMetadata(
      contentType: file.mimeType,
      customMetadata: ownerUid != null ? {'uid': ownerUid} : null,
    );

    final ref = _storage.ref().child(storagePath);
    try {
      final uploadTask = ref.putData(bytes, metadata);
      await uploadTask.whenComplete(() {});
      return await ref.getDownloadURL();
    } catch (error) {
      // surface a clearer message for client-side handling
      throw Exception('Firebase Storage upload failed: $error');
    }
  }

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
