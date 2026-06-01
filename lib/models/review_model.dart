class ReviewModel {
  const ReviewModel({
    required this.reviewId,
    required this.userId,
    required this.userDisplayName,
    required this.movieId,
    required this.movieTitle,
    required this.rating,
    required this.content,
    required this.createdAt,
    this.weather,
    this.location,
    this.imageUrl,
    this.userPhotoUrl,
    this.updatedAt,
  });

  final String reviewId;
  final String userId;
  final String userDisplayName;
  final String movieId;
  final String movieTitle;
  final double rating;
  final String content;
  final String? weather;
  final String? location;
  final String? imageUrl;
  final String? userPhotoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory ReviewModel.fromMap(Map<String, dynamic> data) {
    DateTime? toDateTime(dynamic raw) {
      if (raw is DateTime) {
        return raw;
      }
      if (raw is String && raw.trim().isNotEmpty) {
        return DateTime.tryParse(raw.trim());
      }
      return null;
    }

    final ratingRaw = data['rating'];
    final rating = ratingRaw is num
        ? ratingRaw.toDouble().clamp(0, 5).toDouble()
        : 0.0;

    return ReviewModel(
      reviewId: (data['reviewId'] as String? ?? data['id'] as String? ?? '')
          .trim(),
      userId: (data['userId'] as String? ?? '').trim(),
      userDisplayName: (data['userDisplayName'] as String? ?? 'Ẩn danh').trim(),
      movieId: (data['movieId'] as String? ?? '').trim(),
      movieTitle: (data['movieTitle'] as String? ?? 'Phim chưa rõ').trim(),
      rating: rating,
      content: (data['content'] as String? ?? '').trim(),
      weather: (data['weather'] as String?)?.trim(),
      location: (data['location'] as String?)?.trim(),
      imageUrl: (data['imageUrl'] as String?)?.trim(),
      userPhotoUrl: (data['userPhotoUrl'] as String?)?.trim(),
      createdAt: toDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: toDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reviewId': reviewId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'movieId': movieId,
      'movieTitle': movieTitle,
      'rating': rating,
      'content': content,
      'weather': weather,
      'location': location,
      'imageUrl': imageUrl,
      'userPhotoUrl': userPhotoUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  ReviewModel copyWith({
    String? reviewId,
    String? userId,
    String? userDisplayName,
    String? movieId,
    String? movieTitle,
    double? rating,
    String? content,
    String? weather,
    String? location,
    String? imageUrl,
    String? userPhotoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewModel(
      reviewId: reviewId ?? this.reviewId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      rating: rating ?? this.rating,
      content: content ?? this.content,
      weather: weather ?? this.weather,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
