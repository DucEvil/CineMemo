class TransactionModel {
  const TransactionModel({
    required this.transactionId,
    required this.bookingId,
    required this.userId,
    required this.amount,
    required this.status,
  });

  final String transactionId;
  final String bookingId;
  final String userId;
  final double amount;
  final String status;
}
