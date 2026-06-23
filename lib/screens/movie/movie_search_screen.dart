import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/movie_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/movie_provider.dart';
import '../../services/firebase/firebase_analytics_service.dart';
import '../../services/storage/local_storage_service.dart';
import '../../utils/app_routes.dart';

class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({super.key});

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  static const String _allGenresLabel = 'Tất cả';

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedGenre = _allGenresLabel;
  List<String> _searchHistory = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapSearch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapSearch() async {
    final movieProvider = Provider.of<MovieProvider>(context, listen: false);
    await _loadHistory();

    if (!mounted) {
      return;
    }

    if (movieProvider.nowShowing.isEmpty && movieProvider.comingSoon.isEmpty) {
      await movieProvider.loadHomeData();
    }
  }

  Future<void> _loadHistory() async {
    final storage = Provider.of<LocalStorageService>(context, listen: false);
    final history = await storage.getMovieSearchHistory();
    if (!mounted) {
      return;
    }
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _saveHistory(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return;
    }

    final nextHistory = <String>[
      normalized,
      ..._searchHistory.where(
        (item) => item.toLowerCase() != normalized.toLowerCase(),
      ),
    ];
    if (nextHistory.length > 12) {
      nextHistory.removeRange(12, nextHistory.length);
    }

    setState(() {
      _searchHistory = nextHistory;
    });

    try {
      await Provider.of<LocalStorageService>(
        context,
        listen: false,
      ).cacheMovieSearchHistory(nextHistory);
    } catch (_) {
      // Keep in-memory history even if persistence fails.
    }

    unawaited(_logSearchEvent(normalized));
  }

  Future<void> _logSearchEvent(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return;
    }

    final analyticsService = Provider.of<FirebaseAnalyticsService>(
      context,
      listen: false,
    );
    await analyticsService.logSearch(searchTerm: normalized);
  }

  Future<void> _clearHistory() async {
    setState(() {
      _searchHistory = const [];
    });

    try {
      await Provider.of<LocalStorageService>(
        context,
        listen: false,
      ).clearMovieSearchHistory();
    } catch (_) {
      // Ignore persistence errors.
    }
  }

  Future<bool> _promptLoginForFavorites() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Yêu cầu đăng nhập'),
          content: const Text(
            'Bạn cần đăng nhập để thêm phim vào danh sách yêu thích.',
          ),
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

  Future<void> _handleToggleFavorite(MovieModel movie) async {
    final uid = (Provider.of<AuthProvider>(context, listen: false).uid ?? '')
        .trim();
    if (uid.isEmpty) {
      final shouldLogin = await _promptLoginForFavorites();
      if (shouldLogin && mounted) {
        await Navigator.pushNamed(
          context,
          AppRoutes.login,
          arguments: const {'registerMode': false},
        );
      }
      return;
    }

    await Provider.of<MovieProvider>(
      context,
      listen: false,
    ).toggleFavoriteMovie(movie);
  }

  @override
  Widget build(BuildContext context) {
    final movieProvider = Provider.of<MovieProvider>(context);
    final allMovies = _collectAllMovies(movieProvider);
    final genres = _extractGenres(allMovies);
    final selectedGenre = genres.contains(_selectedGenre)
        ? _selectedGenre
        : _allGenresLabel;

    final normalizedQuery = _query.trim().toLowerCase();
    final filteredMovies = allMovies.where((movie) {
      final byGenre =
          selectedGenre == _allGenresLabel ||
          _movieGenres(movie).contains(selectedGenre);
      if (!byGenre) {
        return false;
      }

      if (normalizedQuery.isEmpty) {
        return true;
      }

      return movie.title.toLowerCase().contains(normalizedQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm phim')),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 78,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                onSubmitted: _saveHistory,
                decoration: InputDecoration(
                  hintText: 'Nhập tên phim...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: const Text(_allGenresLabel),
                    selected: selectedGenre == _allGenresLabel,
                    onSelected: (_) {
                      setState(() {
                        _selectedGenre = _allGenresLabel;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ...genres.map((genre) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(genre),
                        selected: selectedGenre == genre,
                        onSelected: (_) {
                          setState(() {
                            _selectedGenre = genre;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          if (_searchHistory.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    const Text(
                      'Lịch sử tìm kiếm',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearHistory,
                      child: const Text('Xóa tất cả'),
                    ),
                  ],
                ),
              ),
            ),
          if (_searchHistory.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _searchHistory.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(item),
                        onPressed: () {
                          _searchController.text = item;
                          _searchController.selection = TextSelection.collapsed(
                            offset: item.length,
                          );
                          setState(() {
                            _query = item;
                          });
                          unawaited(_logSearchEvent(item));
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (movieProvider.isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredMovies.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  _query.trim().isEmpty
                      ? 'Chưa có dữ liệu phim để tìm kiếm.'
                      : 'Không tìm thấy phim theo từ khóa "$normalizedQuery".',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index.isOdd) {
                    return const SizedBox(height: 8);
                  }

                  final movie = filteredMovies[index ~/ 2];
                  final isFavorite = movieProvider.isFavoriteMovie(movie);

                  return ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    contentPadding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: movie.posterUrl.trim().isNotEmpty
                          ? Image.network(
                              movie.posterUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _fallbackPoster(),
                            )
                          : _fallbackPoster(),
                    ),
                    title: Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${movie.genre} • ${movie.duration} phút',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: isFavorite
                          ? 'Bỏ khỏi yêu thích'
                          : 'Thêm vào yêu thích',
                      onPressed: () {
                        _handleToggleFavorite(movie);
                      },
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite
                            ? const Color(0xFFF43F5E)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    onTap: () async {
                      await _saveHistory(movie.title);
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.pushNamed(
                        context,
                        AppRoutes.movieDetail,
                        arguments: movie,
                      );
                    },
                  );
                }, childCount: filteredMovies.length * 2 - 1),
              ),
            ),
        ],
      ),
    );
  }

  List<MovieModel> _collectAllMovies(MovieProvider provider) {
    final byKey = <String, MovieModel>{};
    for (final movie in [...provider.nowShowing, ...provider.comingSoon]) {
      final key = movie.movieId.trim().isNotEmpty
          ? movie.movieId.trim()
          : movie.title.trim().toLowerCase();
      if (key.isNotEmpty) {
        byKey[key] = movie;
      }
    }

    return byKey.values.toList();
  }

  List<String> _extractGenres(List<MovieModel> movies) {
    final genres = <String>{};
    for (final movie in movies) {
      for (final genre in _movieGenres(movie)) {
        genres.add(genre);
      }
    }
    final list = genres.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  List<String> _movieGenres(MovieModel movie) {
    return movie.genre.split(',').map((item) => item.trim()).where((item) {
      final normalized = item.toLowerCase();
      return item.isNotEmpty &&
          normalized != 'dang cap nhat' &&
          normalized != 'đang cập nhật';
    }).toList();
  }

  Widget _fallbackPoster() {
    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: const Icon(Icons.local_movies_rounded, size: 18),
    );
  }
}
