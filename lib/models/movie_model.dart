import 'package:flutter/material.dart';

enum MovieStatus { nowShowing, comingSoon }

@immutable
class BannerModel {
  const BannerModel({
    required this.title,
    required this.subtitle,
    required this.colorA,
    required this.colorB,
    this.imageUrl = '',
  });

  final String title;
  final String subtitle;
  final Color colorA;
  final Color colorB;
  final String imageUrl;
}

@immutable
class MovieModel {
  const MovieModel({
    required this.movieId,
    required this.title,
    required this.genre,
    required this.cast,
    required this.duration,
    required this.ageLabel,
    required this.status,
    required this.rating,
    this.description = '',
    this.posterUrl = '',
    this.backdropUrl = '',
    this.trailerUrl = '',
    this.galleryUrls = const [],
    this.releaseDate,
  });

  final String movieId;
  final String title;
  final String genre;
  final String cast;
  final int duration;
  final String ageLabel;
  final MovieStatus status;
  final double rating;
  final String description;
  final String posterUrl;
  final String backdropUrl;
  final String trailerUrl;
  final List<String> galleryUrls;
  final DateTime? releaseDate;

  int get minimumAge {
    final match = RegExp(r'\d+').firstMatch(ageLabel);
    if (match == null) {
      return 0;
    }
    return int.tryParse(match.group(0) ?? '0') ?? 0;
  }

  factory MovieModel.fromMap(Map<String, dynamic> map) {
    return MovieModel(
      movieId: map['movieId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      genre: map['genre'] as String? ?? '',
      cast: map['cast'] as String? ?? '',
      duration: map['duration'] as int? ?? 0,
      ageLabel: map['ageLabel'] as String? ?? '13+',
      status: (map['status'] as String? ?? 'nowShowing') == 'comingSoon'
          ? MovieStatus.comingSoon
          : MovieStatus.nowShowing,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String? ?? '',
      posterUrl: map['posterUrl'] as String? ?? '',
      backdropUrl: map['backdropUrl'] as String? ?? '',
      trailerUrl: map['trailerUrl'] as String? ?? '',
      galleryUrls:
          (map['galleryUrls'] as List?)?.whereType<String>().toList() ??
          const <String>[],
      releaseDate: map['releaseDate'] is DateTime
          ? map['releaseDate'] as DateTime
          : DateTime.tryParse(map['releaseDate'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'movieId': movieId,
      'title': title,
      'genre': genre,
      'cast': cast,
      'duration': duration,
      'ageLabel': ageLabel,
      'status': status.name,
      'rating': rating,
      'description': description,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'trailerUrl': trailerUrl,
      'galleryUrls': galleryUrls,
      'releaseDate': releaseDate?.toIso8601String(),
    };
  }

  MovieModel copyWith({
    String? movieId,
    String? title,
    String? genre,
    String? cast,
    int? duration,
    String? ageLabel,
    MovieStatus? status,
    double? rating,
    String? description,
    String? posterUrl,
    String? backdropUrl,
    String? trailerUrl,
    List<String>? galleryUrls,
    DateTime? releaseDate,
  }) {
    return MovieModel(
      movieId: movieId ?? this.movieId,
      title: title ?? this.title,
      genre: genre ?? this.genre,
      cast: cast ?? this.cast,
      duration: duration ?? this.duration,
      ageLabel: ageLabel ?? this.ageLabel,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      description: description ?? this.description,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      trailerUrl: trailerUrl ?? this.trailerUrl,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      releaseDate: releaseDate ?? this.releaseDate,
    );
  }
}
