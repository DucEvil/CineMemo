import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/movie_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/movie_provider.dart';
import '../../utils/app_routes.dart';
import '../../widgets/common/custom_bottom_nav_bar.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  Future<bool> _promptLoginForFavorites(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Yêu cầu đăng nhập'),
          content: const Text('Bạn cần đăng nhập để thêm hoặc bỏ yêu thích.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Đăng nhập'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _handleToggleFavorite(
    BuildContext context,
    MovieModel movie,
  ) async {
    final uid = (Provider.of<AuthProvider>(context, listen: false).uid ?? '').trim();
    if (uid.isEmpty) {
      final shouldLogin = await _promptLoginForFavorites(context);
      if (shouldLogin && context.mounted) {
        await Navigator.pushNamed(
          context,
          AppRoutes.login,
          arguments: const {'registerMode': false},
        );
      }
      return;
    }

    await Provider.of<MovieProvider>(context, listen: false).toggleFavoriteMovie(movie);
  }

  @override
  Widget build(BuildContext context) {
    final movieProvider = Provider.of<MovieProvider>(context);
    final favoriteMovies = movieProvider.favoriteMovies;

    return Scaffold(
      appBar: AppBar(title: const Text('Yêu thích')),
      body: favoriteMovies.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Bạn chưa có phim yêu thích. Bấm biểu tượng tim ở thẻ phim để thêm.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: favoriteMovies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final movie = favoriteMovies[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.movieDetail,
                      arguments: movie,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: movie.posterUrl.trim().isNotEmpty
                              ? Image.network(
                                  movie.posterUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _favoritePosterFallback(),
                                )
                              : _favoritePosterFallback(),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                movie.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${movie.genre} • ${movie.duration} phút',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Bỏ yêu thích',
                          onPressed: () =>
                              _handleToggleFavorite(context, movie),
                          icon: const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFF43F5E),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 3),
    );
  }

  Widget _favoritePosterFallback() {
    return Container(
      width: 56,
      height: 56,
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: const Icon(Icons.local_movies_rounded, size: 18),
    );
  }
}
