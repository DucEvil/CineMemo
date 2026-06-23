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
      throw Exception('Tệp ảnh trống. Vui lòng chọn ảnh khác.');
    }

    final fileName = file.name.trim().isEmpty
        ? 'file_${DateTime.now().millisecondsSinceEpoch}'
        : file.name.trim().replaceAll(RegExp(r'\s+'), '_');
    final storagePath = '$folder/$fileName';

    // Ensure content type is set, default to image/jpeg if not detected
    final contentType = (file.mimeType?.trim().isEmpty ?? true)
        ? 'image/jpeg'
        : file.mimeType;

    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: ownerUid != null ? {'uid': ownerUid} : null,
    );

    final ref = _storage.ref().child(storagePath);
    try {
      final uploadTask = ref.putData(bytes, metadata);
      await uploadTask.whenComplete(() {});
      return await ref.getDownloadURL();
    } catch (error) {
      // Provide clearer error messages based on error type
      if (error.toString().contains('Permission denied')) {
        throw Exception(
          'Không có quyền tải lên. Vui lòng đảm bảo bạn đã đăng nhập.',
        );
      } else if (error.toString().contains('Unauthorized')) {
        throw Exception(
          'Yêu cầu xác thực không thành công. Vui lòng đăng nhập lại.',
        );
      } else if (error.toString().contains('Network')) {
        throw Exception(
          'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối internet và thử lại.',
        );
      }
      throw Exception('Lỗi khi upload ảnh: $error');
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
