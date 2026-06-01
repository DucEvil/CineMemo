import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/movie_model.dart';
import '../cards/movie_card.dart';

class MovieListGrid extends StatelessWidget {
  const MovieListGrid({
    super.key,
    required this.movies,
    this.onTapMovie,
    this.onShareMovie,
    this.onBookMovie,
    this.isFavoriteMovie,
    this.onToggleFavoriteMovie,
  });

  final List<MovieModel> movies;
  final ValueChanged<MovieModel>? onTapMovie;
  final ValueChanged<MovieModel>? onShareMovie;
  final ValueChanged<MovieModel>? onBookMovie;
  final bool Function(MovieModel movie)? isFavoriteMovie;
  final ValueChanged<MovieModel>? onToggleFavoriteMovie;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final config = _GridConfig.fromWidth(
          width: constraints.maxWidth,
          isWeb: kIsWeb,
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: movies.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: config.crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: config.childAspectRatio,
            ),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return InkWell(
                onTap: onTapMovie == null ? null : () => onTapMovie!(movie),
                borderRadius: BorderRadius.circular(16),
                child: MovieCard(
                  movie: movie,
                  onShare: onShareMovie == null
                      ? null
                      : () => onShareMovie!(movie),
                  onBook: onBookMovie == null
                      ? null
                      : () => onBookMovie!(movie),
                  isFavorite: isFavoriteMovie?.call(movie) ?? false,
                  onToggleFavorite: onToggleFavoriteMovie == null
                      ? null
                      : () => onToggleFavoriteMovie!(movie),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GridConfig {
  const _GridConfig({
    required this.crossAxisCount,
    required this.childAspectRatio,
  });

  final int crossAxisCount;
  final double childAspectRatio;

  factory _GridConfig.fromWidth({required double width, required bool isWeb}) {
    if (!isWeb) {
      return const _GridConfig(crossAxisCount: 2, childAspectRatio: 0.51);
    }

    if (width >= 1400) {
      return const _GridConfig(crossAxisCount: 5, childAspectRatio: 0.60);
    }
    if (width >= 1080) {
      return const _GridConfig(crossAxisCount: 4, childAspectRatio: 0.60);
    }
    if (width >= 760) {
      return const _GridConfig(crossAxisCount: 3, childAspectRatio: 0.56);
    }
    if (width >= 360) {
      return const _GridConfig(crossAxisCount: 2, childAspectRatio: 0.50);
    }
    return const _GridConfig(crossAxisCount: 1, childAspectRatio: 0.78);
  }
}
