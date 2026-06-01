class FavoriteModel {
  const FavoriteModel({
    required this.favoriteId,
    required this.userId,
    required this.movieId,
    required this.listType,
  });

  final String favoriteId;
  final String userId;
  final String movieId;
  final String listType;
}
