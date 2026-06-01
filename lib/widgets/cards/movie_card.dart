import 'package:flutter/material.dart';

import '../../models/movie_model.dart';
import '../../utils/app_colors.dart';
import '../buttons/custom_button.dart';
import '../common/age_restriction_badge.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    this.onShare,
    this.onBook,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  final MovieModel movie;
  final VoidCallback? onShare;
  final VoidCallback? onBook;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final isNowShowing = movie.status == MovieStatus.nowShowing;
    final posterUrl = movie.posterUrl.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140B1F3A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.88,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isNowShowing
                            ? const [AppColors.primaryDark, AppColors.primary]
                            : const [Color(0xFF697B93), Color(0xFFC5D1E2)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  if (posterUrl.isNotEmpty)
                    Image.network(
                      posterUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        return const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.local_movies_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        );
                      },
                    )
                  else
                    const Center(
                      child: Icon(
                        Icons.local_movies_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: AgeRestrictionBadge(label: movie.ageLabel),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.30),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onToggleFavorite,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite
                                ? AppColors.highlight
                                : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  movie.genre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${movie.duration} phút',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                if (isNowShowing)
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Chia sẻ',
                          icon: Icons.edit_note_rounded,
                          background: AppColors.surfaceAlt,
                          foreground: AppColors.textPrimary,
                          onPressed: onShare,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CustomButton(
                          text: 'Đặt vé',
                          icon: Icons.local_activity_rounded,
                          background: AppColors.primary,
                          foreground: Colors.white,
                          onPressed: onBook,
                        ),
                      ),
                    ],
                  )
                else
                  CustomButton(
                    text: 'Chia sẻ nhật ký',
                    icon: Icons.edit_note_rounded,
                    background: AppColors.surfaceAlt,
                    foreground: AppColors.textPrimary,
                    onPressed: onShare,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
