import 'package:flutter/material.dart';

enum SeatType { regular, vip, couple }

class SeatViewModel {
  const SeatViewModel({
    required this.code,
    required this.type,
    this.booked = false,
    this.reserved = false,
  });

  final String code;
  final SeatType type;
  final bool booked;
  final bool reserved;
}

class SeatGrid extends StatelessWidget {
  const SeatGrid({
    super.key,
    required this.seats,
    required this.selectedSeatCodes,
    required this.onSeatTap,
  });

  final List<SeatViewModel> seats;
  final Set<String> selectedSeatCodes;
  final ValueChanged<String> onSeatTap;

  static const double _seatGap = 8;
  static final RegExp _seatCodePattern = RegExp(r'^([A-Za-z]+)(\d+)$');

  String _seatRow(String code) {
    final match = _seatCodePattern.firstMatch(code.trim());
    return (match?.group(1) ?? code).toUpperCase();
  }

  int _seatColumn(String code) {
    final match = _seatCodePattern.firstMatch(code.trim());
    return int.tryParse(match?.group(2) ?? '') ?? 0;
  }

  List<_SeatLayoutItem> _buildRowItems(List<SeatViewModel> rowSeats) {
    final sortedSeats = [...rowSeats]
      ..sort((a, b) => _seatColumn(a.code).compareTo(_seatColumn(b.code)));

    final items = <_SeatLayoutItem>[];

    for (var index = 0; index < sortedSeats.length; index++) {
      final current = sortedSeats[index];

      if (current.type == SeatType.couple && index + 1 < sortedSeats.length) {
        final next = sortedSeats[index + 1];
        final currentColumn = _seatColumn(current.code);
        final nextColumn = _seatColumn(next.code);
        final adjacentCouple =
            next.type == SeatType.couple && nextColumn == currentColumn + 1;

        if (adjacentCouple) {
          final selected =
              selectedSeatCodes.contains(current.code) ||
              selectedSeatCodes.contains(next.code);
          final tapCode = selectedSeatCodes.contains(next.code)
              ? next.code
              : current.code;

          items.add(
            _SeatLayoutItem(
              label: '${current.code}-${next.code}',
              tapCode: tapCode,
              type: SeatType.couple,
              booked: current.booked || next.booked,
              reserved: current.reserved || next.reserved,
              selected: selected,
              span: 2,
            ),
          );

          index++;
          continue;
        }
      }

      items.add(
        _SeatLayoutItem(
          label: current.code,
          tapCode: current.code,
          type: current.type,
          booked: current.booked,
          reserved: current.reserved,
          selected: selectedSeatCodes.contains(current.code),
          span: 1,
        ),
      );
    }

    return items;
  }

  Color _backgroundColor(_SeatLayoutItem item) {
    if (item.booked) {
      return const Color(0xFF94A3B8);
    }
    if (item.reserved) {
      return const Color(0xFFF97316);
    }
    if (item.selected) {
      return const Color(0xFF0F172A);
    }

    switch (item.type) {
      case SeatType.regular:
        return const Color(0xFFE2E8F0);
      case SeatType.vip:
        return const Color(0xFFFBBF24);
      case SeatType.couple:
        return const Color(0xFFFDA4AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) {
      return const SizedBox.shrink();
    }

    final groupedSeats = <String, List<SeatViewModel>>{};
    for (final seat in seats) {
      final row = _seatRow(seat.code);
      groupedSeats.putIfAbsent(row, () => <SeatViewModel>[]).add(seat);
    }

    final rows = groupedSeats.keys.toList()..sort();
    final maxColumns = seats
        .map((seat) => _seatColumn(seat.code))
        .fold<int>(0, (max, column) => column > max ? column : max);
    final totalColumns = maxColumns > 0 ? maxColumns : 8;

    return Column(
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final rowItems = _buildRowItems(groupedSeats[rows[rowIndex]]!);
              final slotWidth =
                  (constraints.maxWidth - (totalColumns - 1) * _seatGap) /
                  totalColumns;

              return Row(
                children: [
                  for (
                    var itemIndex = 0;
                    itemIndex < rowItems.length;
                    itemIndex++
                  ) ...[
                    _SeatTile(
                      width:
                          slotWidth * rowItems[itemIndex].span +
                          _seatGap * (rowItems[itemIndex].span - 1),
                      height: slotWidth,
                      background: _backgroundColor(rowItems[itemIndex]),
                      label: rowItems[itemIndex].label,
                      selected: rowItems[itemIndex].selected,
                      booked: rowItems[itemIndex].booked,
                      reserved: rowItems[itemIndex].reserved,
                      onTap:
                          rowItems[itemIndex].booked ||
                              rowItems[itemIndex].reserved
                          ? null
                          : () => onSeatTap(rowItems[itemIndex].tapCode),
                    ),
                    if (itemIndex < rowItems.length - 1)
                      const SizedBox(width: _seatGap),
                  ],
                ],
              );
            },
          ),
          if (rowIndex < rows.length - 1) const SizedBox(height: _seatGap),
        ],
      ],
    );
  }
}

class _SeatLayoutItem {
  const _SeatLayoutItem({
    required this.label,
    required this.tapCode,
    required this.type,
    required this.booked,
    required this.reserved,
    required this.selected,
    required this.span,
  });

  final String label;
  final String tapCode;
  final SeatType type;
  final bool booked;
  final bool reserved;
  final bool selected;
  final int span;
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.width,
    required this.height,
    required this.background,
    required this.label,
    required this.selected,
    required this.booked,
    required this.reserved,
    required this.onTap,
  });

  final double width;
  final double height;
  final Color background;
  final String label;
  final bool selected;
  final bool booked;
  final bool reserved;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: selected || booked || reserved
                  ? Colors.white
                  : const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
