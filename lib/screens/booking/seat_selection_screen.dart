import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/firebase/firebase_firestore_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/layouts/seat_grid.dart';

class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({super.key});

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final List<SeatViewModel> _seats = _buildSeats();
  bool _sessionInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sessionInitialized) {
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, dynamic>) {
      return;
    }

    final showtimeId = (args['showtimeId'] as String? ?? '').trim();
    if (showtimeId.isEmpty) {
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = (auth.uid ?? '').trim();
    if (uid.isEmpty) {
      return;
    }

    _sessionInitialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Provider.of<BookingProvider>(context, listen: false).startSeatSelectionSession(
        userId: uid,
        showtimeId: showtimeId,
      );
    });
  }

  static List<SeatViewModel> _buildSeats() {
    final result = <SeatViewModel>[];
    const rows = ['A', 'B', 'C', 'D', 'E'];

    for (final row in rows) {
      for (var col = 1; col <= 8; col++) {
        final code = '$row$col';
        final type = row == 'D'
            ? SeatType.couple
            : (row == 'C' ? SeatType.vip : SeatType.regular);
        const booked = false;
        result.add(SeatViewModel(code: code, type: type, booked: booked));
      }
    }

    return result;
  }

  double _seatPrice(SeatType type, double basePrice) {
    switch (type) {
      case SeatType.regular:
        return basePrice;
      case SeatType.vip:
        return basePrice * 1.4;
      case SeatType.couple:
        return basePrice * 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, dynamic>) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chọn ghế')),
        body: const Center(child: Text('Thiếu dữ liệu đặt vé.')),
      );
    }

    final basePrice = (args['basePrice'] as num?)?.toDouble() ?? 75000;
    final showtimeId = (args['showtimeId'] as String? ?? '').trim();
    final bookingProvider = Provider.of<BookingProvider>(context);
    final selectedSeatCodes = bookingProvider.selectedSeats;
    final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);

    final seatByCode = {for (final seat in _seats) seat.code: seat};

    final totalPrice = selectedSeatCodes.fold<double>(0, (sum, code) {
      final seat = seatByCode[code];
      if (seat == null) {
        return sum;
      }
      return sum + _seatPrice(seat.type, basePrice);
    });

    final bookedSeatsStream = firestoreService.watchShowtimeBookedSeats(
      showtimeId,
    );
    final heldSeatsStream = firestoreService.watchShowtimeHeldSeats(showtimeId);

    return StreamBuilder<Set<String>>(
      stream: bookedSeatsStream,
      builder: (context, bookedSnapshot) {
        final bookedCodesFromShowtime = bookedSnapshot.data ?? const <String>{};

        return StreamBuilder<Set<String>>(
          stream: heldSeatsStream,
          builder: (context, heldSnapshot) {
            final heldCodesFromShowtime = Set<String>.from(
              heldSnapshot.data ?? const <String>{},
            )..removeWhere(bookedCodesFromShowtime.contains);

            final seats = _seats
                .map(
                  (seat) => SeatViewModel(
                    code: seat.code,
                    type: seat.type,
                    booked:
                        (seat.booked ||
                            bookedCodesFromShowtime.contains(seat.code)) &&
                        !selectedSeatCodes.contains(seat.code),
                    reserved:
                        heldCodesFromShowtime.contains(seat.code) &&
                        !selectedSeatCodes.contains(seat.code),
                  ),
                )
                .toList();

            return PopScope(
              canPop: true,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) {
                  return;
                }
                unawaited(
                  Provider.of<BookingProvider>(context, listen: false).cancelSeatSelectionSession(),
                );
              },
              child: Scaffold(
                appBar: AppBar(title: const Text('Chọn ghế')),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Màn hình',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SeatGrid(
                      seats: seats,
                      selectedSeatCodes: selectedSeatCodes,
                      onSeatTap: (code) =>
                          Provider.of<BookingProvider>(context, listen: false).toggleSeat(code),
                    ),
                    const SizedBox(height: 12),
                    const _SeatLegend(),
                    if (selectedSeatCodes.isNotEmpty &&
                        bookingProvider.reservationExpiresAt != null)
                      Container(
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 18,
                              color: Color(0xFFB45309),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Giữ ghế còn: ${bookingProvider.reservationCountdownLabel}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9A3412),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (bookingProvider.seatSelectionNotice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          bookingProvider.seatSelectionNotice!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Ghế đã chọn: ${selectedSeatCodes.isEmpty ? 'Chưa chọn' : selectedSeatCodes.join(', ')}',
                      style: const TextStyle(color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tổng tiền tạm tính: ${totalPrice.toStringAsFixed(0)} VND',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedSeatCodes.isEmpty
                            ? null
                            : () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.payment,
                                  arguments: {
                                    ...args,
                                    'selectedSeats': selectedSeatCodes.toList(),
                                    'totalPrice': totalPrice,
                                  },
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Tiếp tục thanh toán'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SeatLegend extends StatelessWidget {
  const _SeatLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: const [
        _LegendItem(color: Color(0xFFE2E8F0), label: 'Thường'),
        _LegendItem(color: Color(0xFFFBBF24), label: 'VIP (+40%)'),
        _LegendItem(color: Color(0xFFFDA4AF), label: 'Đôi (x2)'),
        _LegendItem(color: Color(0xFFF97316), label: 'Đang giữ'),
        _LegendItem(color: Color(0xFF94A3B8), label: 'Đã đặt'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
