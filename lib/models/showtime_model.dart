class ShowtimeModel {
  const ShowtimeModel({
    required this.showtimeId,
    required this.movieId,
    required this.theaterId,
    required this.hallName,
    required this.startTime,
    required this.price,
  });

  final String showtimeId;
  final String movieId;
  final String theaterId;
  final String hallName;
  final DateTime startTime;
  final double price;
}
