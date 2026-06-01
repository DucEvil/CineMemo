import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/movie_model.dart';
import '../services/api/vietnam_movie_api.dart';
import '../services/firebase/firebase_firestore_service.dart';
import '../services/storage/local_storage_service.dart';

class MovieProvider extends ChangeNotifier {
  MovieProvider({
    required VietnamMovieApi movieApi,
    required LocalStorageService localStorageService,
    required FirebaseFirestoreService firestoreService,
  }) : _movieApi = movieApi,
       _localStorageService = localStorageService,
       _firestoreService = firestoreService;

  final VietnamMovieApi _movieApi;
  final LocalStorageService _localStorageService;
  final FirebaseFirestoreService _firestoreService;
  static const int _maxGalleryImagesPerMovie = 5;

  bool _isLoading = false;
  String? _error;
  int _tabIndex = 0;
  List<MovieModel> _nowShowing = const [];
  List<MovieModel> _comingSoon = const [];
  final Map<String, MovieModel> _movieDetailCache = <String, MovieModel>{};
  List<String> _favoriteMovieIds = const [];
  String _favoriteScopeKey = 'guest';
  String? _favoriteUserId;

  bool get isLoading => _isLoading;
  String? get error => _error;
  int get tabIndex => _tabIndex;
  List<MovieModel> get nowShowing => _nowShowing;
  List<MovieModel> get comingSoon => _comingSoon;
  List<MovieModel> get currentMovies =>
      _tabIndex == 0 ? _nowShowing : _comingSoon;
  List<String> get favoriteMovieIds => List.unmodifiable(_favoriteMovieIds);
  int get favoriteCount => _favoriteMovieIds.length;

  List<MovieModel> get favoriteMovies {
    final byKey = <String, MovieModel>{
      for (final movie in [
        ..._nowShowing,
        ..._comingSoon,
        ..._movieDetailCache.values,
      ])
        _movieKey(movie): movie,
    };

    final result = <MovieModel>[];
    for (final favoriteId in _favoriteMovieIds) {
      final movie = byKey[favoriteId];
      if (movie != null) {
        result.add(movie);
      }
    }
    return result;
  }

  String _normalizeFavoriteScope(String? scopeKey) {
    final normalized = (scopeKey ?? '').trim();
    return normalized.isEmpty ? 'guest' : normalized;
  }

  List<String> _normalizeFavoriteIds(Iterable<String> ids) {
    return ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _loadFavoriteMovieIdsFromLocal() async {
    final ids = await _localStorageService.getFavoriteMovieIds(
      scopeKey: _favoriteScopeKey,
    );
    _favoriteMovieIds = _normalizeFavoriteIds(ids);
    notifyListeners();
  }

  void syncFavoriteScope(String? scopeKey) {
    final normalizedUserId = (scopeKey ?? '').trim();
    final nextUserId = normalizedUserId.isEmpty ? null : normalizedUserId;
    final nextScope = _normalizeFavoriteScope(nextUserId);

    if (_favoriteScopeKey == nextScope && _favoriteUserId == nextUserId) {
      return;
    }

    _favoriteScopeKey = nextScope;
    _favoriteUserId = nextUserId;
    _favoriteMovieIds = const [];
    notifyListeners();
    unawaited(loadFavoriteMovieIds());
  }

  Future<void> loadFavoriteMovieIds({String? scopeKey}) async {
    if (scopeKey != null) {
      final normalizedUserId = scopeKey.trim();
      _favoriteUserId = normalizedUserId.isEmpty ? null : normalizedUserId;
      _favoriteScopeKey = _normalizeFavoriteScope(_favoriteUserId);
    }

    final favoriteUserId = _favoriteUserId;
    if (favoriteUserId == null) {
      _favoriteMovieIds = const [];
      notifyListeners();
      return;
    }

    try {
      final cloudIds = _normalizeFavoriteIds(
        await _firestoreService.getFavoriteMovieIds(favoriteUserId),
      );

      if (cloudIds.isNotEmpty) {
        _favoriteMovieIds = cloudIds;
      } else {
        final localIds = _normalizeFavoriteIds(
          await _localStorageService.getFavoriteMovieIds(
            scopeKey: _favoriteScopeKey,
          ),
        );
        if (localIds.isNotEmpty) {
          await _firestoreService.seedFavoriteMovies(
            userId: favoriteUserId,
            movieIds: localIds,
          );
        }
        _favoriteMovieIds = localIds;
      }

      notifyListeners();
      unawaited(
        _localStorageService.cacheFavoriteMovieIds(
          _favoriteMovieIds,
          scopeKey: _favoriteScopeKey,
        ),
      );
    } catch (_) {
      try {
        await _loadFavoriteMovieIdsFromLocal();
      } catch (_) {
        _favoriteMovieIds = const [];
        notifyListeners();
      }
    }
  }

  Future<void> loadHomeData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _movieApi.fetchNowShowing(),
        _movieApi.fetchComingSoon(),
      ]);

      final mergedById = <String, MovieModel>{};
      for (final movie in [...results[0], ...results[1]]) {
        mergedById[_movieKey(movie)] = movie;
      }

      final mergedMovies = mergedById.values.toList();
      final nowShowing = mergedMovies
          .where((movie) => movie.status == MovieStatus.nowShowing)
          .toList();
      final comingSoon = mergedMovies
          .where((movie) => movie.status == MovieStatus.comingSoon)
          .toList();

      _nowShowing = nowShowing.isNotEmpty ? nowShowing : results[0];
      _comingSoon = comingSoon.isNotEmpty ? comingSoon : results[1];
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<MovieModel> loadMovieDetail(MovieModel movie) async {
    final key = _movieKey(movie);
    final cached = _movieDetailCache[key];
    if (cached != null) {
      return cached;
    }

    if (movie.movieId.trim().isEmpty) {
      return movie;
    }

    final detail = await _movieApi.fetchMovieDetail(
      movie.movieId,
      fallbackStatus: movie.status,
    );
    if (detail == null) {
      return movie;
    }

    final merged = _mergeMovie(seed: movie, detail: detail);
    _movieDetailCache[key] = merged;
    _upsertMovie(merged);
    notifyListeners();
    return merged;
  }

  bool isFavoriteMovie(MovieModel movie) {
    final key = _movieKey(movie);
    return key.isNotEmpty && _favoriteMovieIds.contains(key);
  }

  Future<void> toggleFavoriteMovie(MovieModel movie) async {
    final key = _movieKey(movie);
    final favoriteUserId = _favoriteUserId;
    if (key.isEmpty || favoriteUserId == null) {
      return;
    }

    final previousFavoriteIds = List<String>.from(_favoriteMovieIds);
    final wasFavorite = previousFavoriteIds.contains(key);

    if (wasFavorite) {
      _favoriteMovieIds = previousFavoriteIds.where((id) => id != key).toList();
    } else {
      _favoriteMovieIds = [...previousFavoriteIds, key];
    }

    notifyListeners();

    try {
      if (wasFavorite) {
        await _firestoreService.deleteFavoriteMovie(
          userId: favoriteUserId,
          movieId: key,
        );
      } else {
        await _firestoreService.upsertFavoriteMovie(
          userId: favoriteUserId,
          movieId: key,
        );
      }

      await _localStorageService.cacheFavoriteMovieIds(
        _favoriteMovieIds,
        scopeKey: _favoriteScopeKey,
      );
    } catch (_) {
      _favoriteMovieIds = previousFavoriteIds;
      notifyListeners();
    }
  }

  void setTabIndex(int value) {
    if (_tabIndex == value) {
      return;
    }
    _tabIndex = value;
    notifyListeners();
  }

  MovieModel? getMovieById(String movieId) {
    for (final movie in [..._nowShowing, ..._comingSoon]) {
      if (movie.movieId == movieId) {
        return movie;
      }
    }
    return null;
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _movieKey(MovieModel movie) {
    final id = movie.movieId.trim();
    if (id.isNotEmpty) {
      return id;
    }
    return movie.title.trim().toLowerCase();
  }

  MovieModel _mergeMovie({
    required MovieModel seed,
    required MovieModel detail,
  }) {
    final mergedGallery = _limitGalleryUrls([
      ...detail.galleryUrls.where((url) => url.trim().isNotEmpty),
      ...seed.galleryUrls.where((url) => url.trim().isNotEmpty),
      if (detail.posterUrl.trim().isNotEmpty) detail.posterUrl.trim(),
      if (detail.backdropUrl.trim().isNotEmpty) detail.backdropUrl.trim(),
      if (seed.posterUrl.trim().isNotEmpty) seed.posterUrl.trim(),
      if (seed.backdropUrl.trim().isNotEmpty) seed.backdropUrl.trim(),
    ]);

    return seed.copyWith(
      movieId: detail.movieId.trim().isNotEmpty ? detail.movieId : seed.movieId,
      title: detail.title.trim().isNotEmpty ? detail.title : seed.title,
      genre: detail.genre.trim().isNotEmpty ? detail.genre : seed.genre,
      cast: detail.cast.trim().isNotEmpty ? detail.cast : seed.cast,
      duration: detail.duration > 0 ? detail.duration : seed.duration,
      ageLabel: detail.ageLabel.trim().isNotEmpty
          ? detail.ageLabel
          : seed.ageLabel,
      status: detail.status,
      rating: detail.rating > 0 ? detail.rating : seed.rating,
      description: detail.description.trim().isNotEmpty
          ? detail.description
          : seed.description,
      posterUrl: detail.posterUrl.trim().isNotEmpty
          ? detail.posterUrl
          : seed.posterUrl,
      backdropUrl: detail.backdropUrl.trim().isNotEmpty
          ? detail.backdropUrl
          : seed.backdropUrl,
      trailerUrl: detail.trailerUrl.trim().isNotEmpty
          ? detail.trailerUrl
          : seed.trailerUrl,
      galleryUrls: mergedGallery,
      releaseDate: detail.releaseDate ?? seed.releaseDate,
    );
  }

  List<String> _limitGalleryUrls(Iterable<String> urls) {
    final limited = <String>[];
    for (final rawUrl in urls) {
      final normalized = rawUrl.trim();
      if (normalized.isEmpty || limited.contains(normalized)) {
        continue;
      }
      limited.add(normalized);
      if (limited.length >= _maxGalleryImagesPerMovie) {
        break;
      }
    }
    return limited;
  }

  void _upsertMovie(MovieModel updatedMovie) {
    bool replaced = false;

    _nowShowing = _nowShowing.map((movie) {
      if (_movieKey(movie) == _movieKey(updatedMovie)) {
        replaced = true;
        return updatedMovie;
      }
      return movie;
    }).toList();

    _comingSoon = _comingSoon.map((movie) {
      if (_movieKey(movie) == _movieKey(updatedMovie)) {
        replaced = true;
        return updatedMovie;
      }
      return movie;
    }).toList();

    _nowShowing = _nowShowing
        .where((movie) => movie.status == MovieStatus.nowShowing)
        .toList();
    _comingSoon = _comingSoon
        .where((movie) => movie.status == MovieStatus.comingSoon)
        .toList();

    if (!replaced) {
      if (updatedMovie.status == MovieStatus.nowShowing) {
        _nowShowing = [..._nowShowing, updatedMovie];
      } else {
        _comingSoon = [..._comingSoon, updatedMovie];
      }
    }
  }
}
