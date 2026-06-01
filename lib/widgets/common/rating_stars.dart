import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    required this.onRatingChanged,
  });

  final double rating;
  final ValueChanged<double> onRatingChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final active = starIndex <= rating.round();
        return IconButton(
          onPressed: () => onRatingChanged(starIndex.toDouble()),
          icon: Icon(
            active ? Icons.star_rounded : Icons.star_border_rounded,
            color: const Color(0xFFF59E0B),
          ),
          visualDensity: VisualDensity.compact,
        );
      }),
    );
  }
}
