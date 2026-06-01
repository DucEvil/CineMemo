class ApiEndpoints {
  static const String nowShowingMovies = '/v1/api/danh-sach/phim-chieu-rap';
  static const String comingSoonMovies = '/v1/api/danh-sach/phim-sap-chieu';
  static const String movieDetail = '/v1/api/phim';
  static const String weatherByCoordinate = '/weather';

  static String movieDetailPath(String movieId) => '$movieDetail/$movieId';
}
