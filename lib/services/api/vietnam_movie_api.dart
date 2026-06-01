import '../../config/app_config.dart';
import '../../models/movie_model.dart';
import 'dio_client.dart';
import 'endpoints.dart';

class VietnamMovieApi {
  VietnamMovieApi({DioClient? client})
    : _client =
          client ??
          DioClient(
            baseUrl: AppConfig.vietnamMovieApiBaseUrl,
            defaultHeaders: {
              if (AppConfig.vietnamMovieApiToken.isNotEmpty)
                'Authorization': 'Bearer ${AppConfig.vietnamMovieApiToken}',
            },
          );

  final DioClient _client;
  static const int _maxGalleryImagesPerMovie = 5;

  Future<List<MovieModel>> fetchNowShowing() {
    return _fetchMovies(status: MovieStatus.nowShowing);
  }

  Future<List<MovieModel>> fetchComingSoon() {
    return _fetchMovies(status: MovieStatus.comingSoon);
  }

  Future<MovieModel?> fetchMovieDetail(
    String movieId, {
    MovieStatus? fallbackStatus,
  }) async {
    if (!AppConfig.hasMovieApi) {
      return _findInFallback(movieId);
    }

    try {
      final response = await _client.get(ApiEndpoints.movieDetailPath(movieId));
      final item = _extractDetailItem(response.data);
      if (item == null) {
        return _findInFallback(movieId);
      }
      final imageBaseUrl = _extractImageBaseUrl(response.data);
      final mapped = _mapMovie(
        item,
        _parseStatus(item, fallback: fallbackStatus ?? MovieStatus.nowShowing),
        imageBaseUrl: imageBaseUrl,
      );

      final extraGallery = _extractGalleryUrlsFromPayload(
        response.data,
        imageBaseUrl,
      );
      final mergedGallery = _limitGalleryUrls([
        ...mapped.galleryUrls,
        if (mapped.posterUrl.trim().isNotEmpty) mapped.posterUrl.trim(),
        if (mapped.backdropUrl.trim().isNotEmpty) mapped.backdropUrl.trim(),
        ...extraGallery,
      ]);

      return mapped.copyWith(galleryUrls: mergedGallery);
    } catch (_) {
      return _findInFallback(movieId);
    }
  }

  Future<List<String>> fetchMovieShowtimes(String movieId) async {
    final normalizedId = movieId.trim();
    if (normalizedId.isEmpty || !AppConfig.hasMovieApi) {
      return const [];
    }

    try {
      final response = await _client.get(ApiEndpoints.movieDetailPath(movieId));
      final item = _extractDetailItem(response.data);
      if (item == null) {
        return const [];
      }

      final showtimes = _extractShowtimeLabels(item['showtimes']);
      if (showtimes.isNotEmpty) {
        return showtimes;
      }

      return _extractShowtimeLabels(item['episodes']);
    } catch (_) {
      return const [];
    }
  }

  Future<List<MovieModel>> _fetchMovies({required MovieStatus status}) async {
    if (!AppConfig.hasMovieApi) {
      return _fallbackMovies(status);
    }

    try {
      final path = status == MovieStatus.nowShowing
          ? ApiEndpoints.nowShowingMovies
          : ApiEndpoints.comingSoonMovies;
      final response = await _client.get(path);
      final items = _extractList(response.data);
      final imageBaseUrl = _extractImageBaseUrl(response.data);

      if (items.isEmpty) {
        return _fallbackMovies(status);
      }

      return items
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => _mapMovie(item, status, imageBaseUrl: imageBaseUrl))
          .toList();
    } catch (_) {
      return _fallbackMovies(status);
    }
  }

  MovieModel? _findInFallback(String movieId) {
    final all = [
      ..._fallbackMovies(MovieStatus.nowShowing),
      ..._fallbackMovies(MovieStatus.comingSoon),
    ];
    for (final movie in all) {
      if (movie.movieId == movieId) {
        return movie;
      }
    }
    return null;
  }

  MovieModel _mapMovie(
    Map<dynamic, dynamic> raw,
    MovieStatus fallbackStatus, {
    String imageBaseUrl = '',
  }) {
    final data = raw.map((key, value) => MapEntry(key.toString(), value));

    final categories =
        data['genre'] ?? data['categories'] ?? data['category'] ?? data['type'];
    final castValue = data['cast'] ?? data['actors'] ?? data['actor'];
    final runtime =
        data['duration'] ??
        data['runtime'] ??
        data['time'] ??
        data['episode_time'] ??
        data['movie_time'];
    final posterUrlRaw =
        _pickString(data, const ['posterUrl', 'thumb_url', 'poster_url']) ?? '';
    final backdropUrlRaw =
        _pickString(data, const [
          'backdropUrl',
          'backdrop_url',
          'poster_url',
        ]) ??
        '';
    final galleryUrls = _extractGalleryUrls(data, imageBaseUrl);

    final trailerUrl =
        _pickString(data, const ['trailerUrl', 'trailer_url', 'trailer']) ?? '';

    final title =
        _pickString(data, const [
          'title',
          'name',
          'movie_name',
          'origin_name',
        ]) ??
        'Unknown movie';
    final genre = _normalizeList(categories);
    final cast = _normalizeList(castValue);
    final description = _sanitizeDescription(
      _pickString(data, const ['description', 'content', 'overview']) ?? '',
    );

    final normalizedPoster = _normalizeImageUrl(posterUrlRaw, imageBaseUrl);
    final normalizedBackdrop = _normalizeImageUrl(backdropUrlRaw, imageBaseUrl);

    return MovieModel(
      movieId: _pickString(data, const ['movieId', 'id', 'slug']) ?? '',
      title: title,
      genre: genre,
      cast: cast,
      duration: _parseDuration(runtime),
      ageLabel: _resolveAgeLabel(
        data,
        title: title,
        genre: genre,
        description: description,
      ),
      status: _parseStatus(data, fallback: fallbackStatus),
      rating:
          _pickNum(data, const [
            'rating',
            'imdb',
            'vote_average',
            'tmdb',
          ])?.toDouble() ??
          0,
      description: description,
      posterUrl: normalizedPoster,
      backdropUrl: normalizedBackdrop,
      trailerUrl: _normalizeTrailerUrl(trailerUrl),
      galleryUrls: galleryUrls,
      releaseDate: DateTime.tryParse(
        _pickString(data, const ['releaseDate', 'release_date']) ?? '',
      ),
    );
  }

  String _resolveAgeLabel(
    Map<String, dynamic> map, {
    required String title,
    required String genre,
    required String description,
  }) {
    final explicit = _normalizeAgeLabel(
      _pickString(map, const [
        'ageLabel',
        'age_rating',
        'classification',
        'censorship',
        'film_rating',
        'filmRating',
        'mpaa',
      ]),
    );
    if (explicit != null) {
      return explicit;
    }

    final normalizedText = '$title $genre $description'.toLowerCase();

    if (_containsAny(normalizedText, const [
      'kinh dị',
      'kinh di',
      'horror',
      'slasher',
      'gore',
      'zombie',
      'ma ám',
      'ma am',
    ])) {
      return '18+';
    }

    if (_containsAny(normalizedText, const [
      'hoạt hình',
      'hoat hinh',
      'thiếu nhi',
      'thieu nhi',
      'trẻ em',
      'tre em',
      'gia đình',
      'gia dinh',
      'family',
      'animation',
      'kids',
      'children',
    ])) {
      return 'P';
    }

    return '13+';
  }

  bool _containsAny(String source, List<String> needles) {
    for (final needle in needles) {
      if (source.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  String? _normalizeAgeLabel(String? raw) {
    if (raw == null) {
      return null;
    }

    final text = raw.trim();
    if (text.isEmpty) {
      return null;
    }

    final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized == 'p' ||
        normalized == 'k' ||
        normalized == 'g' ||
        normalized.contains('allages') ||
        normalized.contains('moiluoituoi')) {
      return 'P';
    }

    if (normalized.contains('18') ||
        normalized.contains('t18') ||
        normalized.contains('c18') ||
        normalized.contains('r18') ||
        normalized.contains('nc17')) {
      return '18+';
    }

    if (normalized.contains('16') ||
        normalized.contains('t16') ||
        normalized.contains('c16')) {
      return '16+';
    }

    if (normalized.contains('13') ||
        normalized.contains('t13') ||
        normalized.contains('pg13')) {
      return '13+';
    }

    final ageMatch = RegExp(r'\d{1,2}').firstMatch(normalized);
    if (ageMatch != null) {
      final age = int.tryParse(ageMatch.group(0)!);
      if (age == null) {
        return null;
      }
      if (age >= 18) {
        return '18+';
      }
      if (age >= 16) {
        return '16+';
      }
      if (age >= 13) {
        return '13+';
      }
      return 'P';
    }

    return null;
  }

  List<dynamic> _extractList(dynamic payload) {
    if (payload is List<dynamic>) {
      return payload;
    }
    if (payload is Map<dynamic, dynamic>) {
      for (final key in const ['data', 'items', 'results', 'movies']) {
        final nested = payload[key];
        if (nested is List<dynamic>) {
          return nested;
        }
      }
      final data = payload['data'];
      if (data is Map<dynamic, dynamic>) {
        final items = data['items'];
        if (items is List<dynamic>) {
          return items;
        }
      }
    }
    return const [];
  }

  Map<dynamic, dynamic>? _extractDetailItem(dynamic payload) {
    if (payload is Map<dynamic, dynamic>) {
      final data = payload['data'];
      if (data is Map<dynamic, dynamic>) {
        final item = data['item'];
        if (item is Map<dynamic, dynamic>) {
          return item;
        }
      }
      return payload;
    }
    return null;
  }

  String _extractImageBaseUrl(dynamic payload) {
    if (payload is Map<dynamic, dynamic>) {
      final data = payload['data'];
      if (data is Map<dynamic, dynamic>) {
        final imageBase = data['APP_DOMAIN_CDN_IMAGE'];
        if (imageBase is String && imageBase.isNotEmpty) {
          return imageBase;
        }
      }
      final imageBase = payload['APP_DOMAIN_CDN_IMAGE'];
      if (imageBase is String && imageBase.isNotEmpty) {
        return imageBase;
      }
    }
    return '';
  }

  String? _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  bool? _pickBool(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') {
          return true;
        }
        if (normalized == 'false' || normalized == '0') {
          return false;
        }
      }
    }
    return null;
  }

  num? _pickNum(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) {
        return value;
      }
      if (value is Map) {
        for (final nestedKey in const [
          'rating',
          'vote_average',
          'voteAverage',
        ]) {
          final nestedValue = value[nestedKey];
          if (nestedValue is num) {
            return nestedValue;
          }
          if (nestedValue is String) {
            final parsed = num.tryParse(nestedValue);
            if (parsed != null) {
              return parsed;
            }
          }
        }
      }
      if (value is String) {
        final parsed = num.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  String _normalizeList(dynamic value) {
    if (value is List) {
      return value
          .map((item) {
            if (item is String) {
              return item;
            }
            if (item is Map && item['name'] is String) {
              return item['name'] as String;
            }
            return null;
          })
          .whereType<String>()
          .join(', ');
    }
    if (value is String) {
      return value;
    }
    return 'Dang cap nhat';
  }

  int _parseDuration(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(normalized) ?? 110;
    }
    return 110;
  }

  MovieStatus _parseStatus(Map<dynamic, dynamic> map, {MovieStatus? fallback}) {
    final isCinema = _pickBool(map, const [
      'chieurap',
      'is_cinema',
      'isCinema',
    ]);
    final episodeCurrent = (map['episode_current'] ?? '')
        .toString()
        .toLowerCase();
    if (episodeCurrent.contains('trailer') ||
        episodeCurrent.contains('teaser')) {
      return MovieStatus.comingSoon;
    }
    if (isCinema == true) {
      return MovieStatus.nowShowing;
    }
    if (isCinema == false) {
      return MovieStatus.comingSoon;
    }

    final value =
        (map['status'] ?? map['movieStatus'] ?? map['episode_current'] ?? '')
            .toString()
            .toLowerCase();
    if (value.contains('trailer') || value.contains('sap')) {
      return MovieStatus.comingSoon;
    }
    if (value.contains('coming')) {
      return MovieStatus.comingSoon;
    }
    if (value.contains('now') ||
        value.contains('dang') ||
        value.contains('ongoing') ||
        value.contains('tap')) {
      return MovieStatus.nowShowing;
    }
    return fallback ?? MovieStatus.nowShowing;
  }

  String _normalizeImageUrl(String rawUrl, String imageBaseUrl) {
    if (rawUrl.isEmpty) {
      return '';
    }
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }

    final normalizedRaw = rawUrl.startsWith('//') ? 'https:$rawUrl' : rawUrl;
    if (normalizedRaw.startsWith('http://') ||
        normalizedRaw.startsWith('https://')) {
      return normalizedRaw;
    }

    if (imageBaseUrl.isNotEmpty) {
      final base = imageBaseUrl.endsWith('/')
          ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
          : imageBaseUrl;
      final rawPath = normalizedRaw.startsWith('/')
          ? normalizedRaw.substring(1)
          : normalizedRaw;
      final lowerRawPath = rawPath.toLowerCase();
      final baseLower = base.toLowerCase();
      final canTreatAsMovieImage = _looksLikeImageRawValue(rawPath);

      final needsUploadsPrefix =
          canTreatAsMovieImage &&
          ((!rawPath.contains('/') && !baseLower.contains('/uploads/movies')) ||
              lowerRawPath.startsWith('movies/'));
      if (needsUploadsPrefix) {
        final normalizedFile = lowerRawPath.startsWith('movies/')
            ? rawPath.substring(7)
            : rawPath;
        return '$base/uploads/movies/$normalizedFile';
      }

      final path = normalizedRaw.startsWith('/')
          ? normalizedRaw
          : '/$normalizedRaw';
      return '$base$path';
    }

    return normalizedRaw;
  }

  String _normalizeTrailerUrl(String rawTrailerUrl) {
    final source = rawTrailerUrl.trim();
    if (source.isEmpty) {
      return '';
    }

    final normalized = source.startsWith('//') ? 'https:$source' : source;
    final youtubeId = _extractYoutubeId(normalized);
    if (youtubeId != null) {
      return 'https://www.youtube.com/watch?v=$youtubeId';
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    return '';
  }

  String? _extractYoutubeId(String rawUrl) {
    final directId = RegExp(r'^[A-Za-z0-9_-]{11}$');
    if (directId.hasMatch(rawUrl)) {
      return rawUrl;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return null;
    }

    final host = uri.host.toLowerCase();
    if (host.contains('youtu.be')) {
      if (uri.pathSegments.isEmpty) {
        return null;
      }
      return uri.pathSegments.first;
    }

    if (host.contains('youtube.com') || host.contains('youtube-nocookie.com')) {
      final queryId = uri.queryParameters['v'];
      if (queryId != null && queryId.isNotEmpty) {
        return queryId;
      }

      final segments = uri.pathSegments;
      final embedIndex = segments.indexOf('embed');
      if (embedIndex >= 0 && embedIndex + 1 < segments.length) {
        return segments[embedIndex + 1];
      }

      final shortsIndex = segments.indexOf('shorts');
      if (shortsIndex >= 0 && shortsIndex + 1 < segments.length) {
        return segments[shortsIndex + 1];
      }
    }

    return null;
  }

  List<String> _extractShowtimeLabels(dynamic raw) {
    final labels = <String>{};
    final matcher = RegExp(r'(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?!\d)');

    void collect(dynamic value) {
      if (value is String) {
        for (final match in matcher.allMatches(value)) {
          final hourRaw = match.group(1);
          final minuteRaw = match.group(2);
          if (hourRaw == null || minuteRaw == null) {
            continue;
          }
          final hour = int.tryParse(hourRaw);
          final minute = int.tryParse(minuteRaw);
          if (hour == null || minute == null) {
            continue;
          }
          labels.add(
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
          );
        }
        return;
      }

      if (value is List) {
        for (final item in value) {
          collect(item);
        }
        return;
      }

      if (value is Map) {
        for (final nested in value.values) {
          collect(nested);
        }
      }
    }

    collect(raw);
    final result = labels.toList()
      ..sort(
        (a, b) => _timeLabelToMinutes(a).compareTo(_timeLabelToMinutes(b)),
      );
    return result;
  }

  int _timeLabelToMinutes(String label) {
    final parts = label.split(':');
    if (parts.length != 2) {
      return 24 * 60;
    }
    final hour = int.tryParse(parts[0]) ?? 24;
    final minute = int.tryParse(parts[1]) ?? 0;
    return (hour * 60) + minute;
  }

  String _sanitizeDescription(String input) {
    if (input.trim().isEmpty) {
      return '';
    }

    var output = input;
    output = output.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );
    output = output.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    output = output.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');
    output = output.replaceAll(RegExp(r'<li>', caseSensitive: false), '- ');
    output = output.replaceAll(RegExp(r'<[^>]*>'), '');

    const entities = <String, String>{
      '&nbsp;': ' ',
      '&amp;': '&',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
      '&lt;': '<',
      '&gt;': '>',
    };

    entities.forEach((key, value) {
      output = output.replaceAll(key, value);
    });

    output = output.replaceAll(RegExp(r'\r\n?'), '\n');
    output = output.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    output = output.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return output.trim();
  }

  List<String> _extractGalleryUrls(
    Map<String, dynamic> data,
    String imageBaseUrl,
  ) {
    final result = <String>[];

    void addImage(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        final normalized = _normalizeImageUrl(value.trim(), imageBaseUrl);
        if (normalized.isNotEmpty && !_isLikelyImageUrl(normalized)) {
          return;
        }
        if (normalized.isNotEmpty && !result.contains(normalized)) {
          result.add(normalized);
        }
        return;
      }
      if (value is Map) {
        final candidate =
            value['url'] ??
            value['image'] ??
            value['src'] ??
            value['path'] ??
            value['thumb_url'] ??
            value['poster_url'];
        addImage(candidate);
      }
    }

    for (final key in const [
      'thumb_url',
      'poster_url',
      'posterUrl',
      'backdrop_url',
      'backdropUrl',
      'banner_url',
      'bannerUrl',
      'cover_url',
      'coverUrl',
      'landscape_url',
      'landscapeUrl',
      'screenshot_url',
      'screenshotUrl',
      'image_url',
      'imageUrl',
      'image',
      'thumbnail',
    ]) {
      addImage(data[key]);
    }

    for (final key in const [
      'images',
      'gallery',
      'backdrops',
      'posters',
      'banners',
      'screenshots',
      'stills',
      'photos',
      'thumbnails',
      'galleryUrls',
      'gallery_urls',
      'imageUrls',
      'image_urls',
    ]) {
      final value = data[key];
      if (value is List) {
        for (final item in value) {
          addImage(item);
        }
      }
    }

    for (final extra in _extractGalleryUrlsFromPayload(data, imageBaseUrl)) {
      if (!result.contains(extra)) {
        result.add(extra);
      }
    }

    return _limitGalleryUrls(result);
  }

  List<String> _limitGalleryUrls(Iterable<String> urls) {
    final limited = <String>[];
    for (final rawUrl in urls) {
      final normalized = rawUrl.trim();
      if (normalized.isEmpty ||
          !_isLikelyImageUrl(normalized) ||
          limited.contains(normalized)) {
        continue;
      }
      limited.add(normalized);
      if (limited.length >= _maxGalleryImagesPerMovie) {
        break;
      }
    }
    return limited;
  }

  List<String> _extractGalleryUrlsFromPayload(
    dynamic payload,
    String imageBaseUrl,
  ) {
    final result = <String>[];

    void add(dynamic value, {String key = ''}) {
      if (result.length >= 24 || value == null) {
        return;
      }

      if (value is String) {
        final raw = value.trim();
        if (raw.isEmpty) {
          return;
        }

        if (!_looksLikeImageRawValue(raw)) {
          return;
        }

        final normalized = _normalizeImageUrl(raw, imageBaseUrl);
        if (normalized.isEmpty) {
          return;
        }

        final shouldKeep = _isLikelyImageUrl(normalized);
        if (!shouldKeep) {
          return;
        }

        if (!result.contains(normalized)) {
          result.add(normalized);
        }
        return;
      }

      if (value is List) {
        for (final item in value) {
          add(item, key: key);
          if (result.length >= 24) {
            break;
          }
        }
        return;
      }

      if (value is Map) {
        for (final entry in value.entries) {
          add(entry.value, key: entry.key.toString().toLowerCase());
          if (result.length >= 24) {
            break;
          }
        }
      }
    }

    add(payload);
    return result;
  }

  bool _isLikelyImageUrl(String value) {
    final lower = value.toLowerCase();
    if (_hasImageFileExtension(lower)) {
      return true;
    }

    if (lower.contains('image.tmdb.org/t/p/') ||
        lower.contains('img.youtube.com/') ||
        lower.contains('ytimg.com/')) {
      return true;
    }

    if (lower.contains('/image/upload/')) {
      return true;
    }

    return false;
  }

  bool _looksLikeImageRawValue(String value) {
    final lower = value.toLowerCase();
    if (_hasImageFileExtension(lower)) {
      return true;
    }

    if (lower.startsWith('movies/') ||
        lower.startsWith('/movies/') ||
        lower.startsWith('uploads/movies/') ||
        lower.startsWith('/uploads/movies/')) {
      return true;
    }

    if (lower.contains('/image/upload/') ||
        lower.contains('thumb') ||
        lower.contains('poster') ||
        lower.contains('backdrop') ||
        lower.contains('thumbnail') ||
        lower.contains('screenshot') ||
        lower.contains('banner') ||
        lower.contains('cover')) {
      return true;
    }

    return false;
  }

  bool _hasImageFileExtension(String value) {
    final sanitized = value.split('?').first.split('#').first;
    return sanitized.endsWith('.jpg') ||
        sanitized.endsWith('.jpeg') ||
        sanitized.endsWith('.png') ||
        sanitized.endsWith('.webp') ||
        sanitized.endsWith('.avif') ||
        sanitized.endsWith('.gif') ||
        sanitized.endsWith('.bmp') ||
        sanitized.endsWith('.svg');
  }

  List<MovieModel> _fallbackMovies(MovieStatus status) {
    if (status == MovieStatus.nowShowing) {
      return const [
        MovieModel(
          movieId: 'local-m1',
          title: 'Lat Mat: Tam Ve Dinh Menh',
          genre: 'Hanh dong, Tam ly',
          cast: 'Ly Hai, Kha Ngan',
          duration: 128,
          ageLabel: '16+',
          status: MovieStatus.nowShowing,
          rating: 4.4,
          description: 'Bo phim hanh dong tam ly voi nhieu pha twist.',
          trailerUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        MovieModel(
          movieId: 'local-m2',
          title: 'Mai',
          genre: 'Tinh cam, Hai huoc',
          cast: 'Tran Thanh, Phuong Anh Dao',
          duration: 131,
          ageLabel: '13+',
          status: MovieStatus.nowShowing,
          rating: 4.1,
          description: 'Cau chuyen tinh cam voi nhieu cung bac cam xuc.',
          trailerUrl: 'https://www.youtube.com/watch?v=oHg5SJYRHA0',
        ),
      ];
    }
    return const [
      MovieModel(
        movieId: 'local-c1',
        title: 'Quy Cau',
        genre: 'Kinh di, Bi an',
        cast: 'Thu Trang, Quang Tuan',
        duration: 112,
        ageLabel: '18+',
        status: MovieStatus.comingSoon,
        rating: 0,
        description: 'Phim kinh di bi an sap khoi chieu.',
      ),
      MovieModel(
        movieId: 'local-c2',
        title: 'Nguoi Mat Tich',
        genre: 'Hinh su, Giat gan',
        cast: 'Ninh Duong Lan Ngoc, Quoc Huy',
        duration: 118,
        ageLabel: '16+',
        status: MovieStatus.comingSoon,
        rating: 0,
        description: 'Vu mat tich kho hieu va hanh trinh truy tim su that.',
      ),
    ];
  }
}
