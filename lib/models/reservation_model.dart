class ReservationModel {
  const ReservationModel({
    required this.reservationId,
    required this.userId,
    required this.showtimeId,
    required this.expiresAt,
  });

  final String reservationId;
  final String userId;
  final String showtimeId;
  final DateTime expiresAt;
}
