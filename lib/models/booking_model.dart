class BookingModel {
  const BookingModel({
    required this.bookingId,
    required this.userId,
    required this.showtimeId,
    required this.totalPrice,
    required this.status,
  });

  final String bookingId;
  final String userId;
  final String showtimeId;
  final double totalPrice;
  final String status;
}
