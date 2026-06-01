import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/movie_model.dart';
import '../../models/review_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/movie_provider.dart';
import '../../providers/review_provider.dart';
import '../../services/firebase/firebase_firestore_service.dart';
import '../../services/location/location_service.dart';
import '../../services/storage/cloudinary_service.dart';
import '../../services/weather/weather_service.dart';
import '../../widgets/common/rating_stars.dart';

class CreateReviewScreen extends StatefulWidget {
  const CreateReviewScreen({super.key});

  @override
  State<CreateReviewScreen> createState() => _CreateReviewScreenState();
}

class _CreateReviewScreenState extends State<CreateReviewScreen> {
  final TextEditingController _movieTitleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _initializedFromArgs = false;
  MovieModel? _selectedMovie;
  String? _selectedMovieOptionKey;
  String _prefilledMovieIdFromArgs = '';
  ReviewModel? _editingReview;
  double _rating = 4;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _submitting = false;
  String? _weatherSummary;
  String? _locationSummary;
  double? _locationLatitude;
  double? _locationLongitude;

  String _movieOptionKey(MovieModel movie) {
    final movieId = movie.movieId.trim();
    if (movieId.isNotEmpty) {
      return 'id:$movieId';
    }
    return 'title:${movie.title.trim().toLowerCase()}';
  }

  String _normalizedTitle(String value) {
    return value.trim().toLowerCase();
  }

  MovieModel _buildDropdownMovieOption({
    required String title,
    String movieId = '',
  }) {
    return MovieModel(
      movieId: movieId.trim(),
      title: title.trim(),
      genre: '',
      cast: '',
      duration: 0,
      ageLabel: '13+',
      status: MovieStatus.nowShowing,
      rating: 0,
    );
  }

  List<MovieModel> _availableMovies(MovieProvider movieProvider) {
    final byKey = <String, MovieModel>{};
    for (final movie in [
      ...movieProvider.nowShowing,
      ...movieProvider.comingSoon,
    ]) {
      final key = _movieOptionKey(movie);
      byKey.putIfAbsent(key, () => movie);
    }

    final selectedMovie = _selectedMovie;
    if (selectedMovie != null) {
      final selectedKey = _movieOptionKey(selectedMovie);
      final selectedTitle = _normalizedTitle(selectedMovie.title);
      final hasSameTitle = byKey.values.any(
        (movie) => _normalizedTitle(movie.title) == selectedTitle,
      );
      if (!hasSameTitle) {
        byKey.putIfAbsent(selectedKey, () => selectedMovie);
      }
    }

    final movies = byKey.values.toList();
    movies.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return movies;
  }

  void _applySelectedMovie(MovieModel movie) {
    _selectedMovie = movie;
    _selectedMovieOptionKey = _movieOptionKey(movie);
    final movieId = movie.movieId.trim();
    if (movieId.isNotEmpty) {
      _prefilledMovieIdFromArgs = movieId;
    }
    _movieTitleController.text = movie.title;
  }

  void _hydrateCoordinateFromLocationText(String? locationText) {
    final source = (locationText ?? '').trim();
    if (source.isEmpty) {
      return;
    }

    final match = RegExp(
      r'(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(source);
    if (match == null) {
      return;
    }

    final lat = double.tryParse(match.group(1) ?? '');
    final lng = double.tryParse(match.group(2) ?? '');
    if (lat == null || lng == null) {
      return;
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return;
    }

    _locationLatitude = lat;
    _locationLongitude = lng;
  }

  String? _buildOpenStreetMapTileUrl() {
    final lat = _locationLatitude;
    final lng = _locationLongitude;
    if (lat == null || lng == null) {
      return null;
    }

    const zoom = 15;
    final clampedLat = lat.clamp(-85.05112878, 85.05112878).toDouble();
    final normalizedLng = (((lng + 180) % 360) + 360) % 360 - 180;
    final tileCount = math.pow(2, zoom).toDouble();
    final latRad = clampedLat * math.pi / 180;

    final xTile = (((normalizedLng + 180) / 360) * tileCount).floor().clamp(
      0,
      tileCount.toInt() - 1,
    );
    final yRatio =
        (1 - (math.log(math.tan(latRad) + (1 / math.cos(latRad))) / math.pi)) /
        2;
    final yTile = (yRatio * tileCount).floor().clamp(0, tileCount.toInt() - 1);

    return Uri.https(
      'tile.openstreetmap.org',
      '/$zoom/$xTile/$yTile.png',
    ).toString();
  }

  String? _buildYandexStaticMapUrl() {
    final lat = _locationLatitude;
    final lng = _locationLongitude;
    if (lat == null || lng == null) {
      return null;
    }

    final latText = lat.toStringAsFixed(6);
    final lngText = lng.toStringAsFixed(6);

    return Uri.https('static-maps.yandex.ru', '/1.x/', {
      'll': '$lngText,$latText',
      'zoom': '15',
      'size': '650,350',
      'l': 'map',
      'pt': '$lngText,$latText,pm2rdm',
    }).toString();
  }

  @override
  void dispose() {
    _movieTitleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromArgs) {
      return;
    }

    _initializedFromArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is MovieModel) {
      _applySelectedMovie(args);
      _loadWeatherAndLocation();
      return;
    }

    if (args is Map<String, dynamic>) {
      final movieArg = args['movie'];
      if (movieArg is MovieModel) {
        _applySelectedMovie(movieArg);
      }

      final reviewArg = args['review'];
      if (reviewArg is ReviewModel) {
        _editingReview = reviewArg;
        _movieTitleController.text = reviewArg.movieTitle;
        _contentController.text = reviewArg.content;
        _rating = reviewArg.rating;
        _weatherSummary = reviewArg.weather;
        _locationSummary = reviewArg.location;
        _hydrateCoordinateFromLocationText(_locationSummary);
        _prefilledMovieIdFromArgs = reviewArg.movieId.trim();
        final reviewMovieTitle = reviewArg.movieTitle.trim();
        if (reviewMovieTitle.isNotEmpty) {
          _applySelectedMovie(
            _buildDropdownMovieOption(
              title: reviewMovieTitle,
              movieId: _prefilledMovieIdFromArgs,
            ),
          );
        }
        return;
      }

      final movieIdArg = (args['movieId'] as String? ?? '').trim();
      if (movieIdArg.isNotEmpty) {
        _prefilledMovieIdFromArgs = movieIdArg;
      }

      final movieTitleArg = (args['movieTitle'] as String? ?? '').trim();
      if (movieTitleArg.isNotEmpty) {
        _applySelectedMovie(
          _buildDropdownMovieOption(title: movieTitleArg, movieId: movieIdArg),
        );
      }

      if (_selectedMovie != null) {
        _movieTitleController.text = _selectedMovie!.title;
      }
    }

    if (_movieTitleController.text.trim().isEmpty) {
      _movieTitleController.text = _selectedMovie?.title ?? '';
    }

    _loadWeatherAndLocation();
  }

  Future<void> _loadWeatherAndLocation() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final weatherService = Provider.of<WeatherService>(context, listen: false);

    final position = await locationService.getCurrentPosition();
    if (position == null || !mounted) {
      return;
    }

    setState(() {
      _locationLatitude = position.latitude;
      _locationLongitude = position.longitude;
      _locationSummary =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
    });

    final weather = await weatherService.getCurrentWeather(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (weather == null || !mounted) {
      return;
    }

    setState(() {
      _weatherSummary =
          '${weather.temperature.toStringAsFixed(1)}°C, ${weather.description} (${weather.city})';
    });
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    final file = await _imagePicker.pickImage(source: source, imageQuality: 80);

    if (file == null || !mounted) {
      return;
    }

    final imageBytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedImage = file;
      _selectedImageBytes = imageBytes;
    });
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Chọn nguồn ảnh',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Chụp từ camera'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Chọn từ thư viện'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    try {
      await _pickImageFromSource(source);
    } catch (_) {
      if (!mounted) {
        return;
      }
      final sourceLabel = source == ImageSource.camera ? 'camera' : 'thư viện';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lấy ảnh từ $sourceLabel. Vui lòng thử lại.'),
        ),
      );
    }
  }

  Future<void> _submitReview() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = (auth.uid ?? '').trim();
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để lưu nhật ký.')),
      );
      return;
    }

    final movieProvider = Provider.of<MovieProvider>(context, listen: false);
    final availableMovies = _availableMovies(movieProvider);
    final moviesByKey = {
      for (final movie in availableMovies) _movieOptionKey(movie): movie,
    };

    MovieModel? selectedMovie = _selectedMovie;
    final selectedMovieOptionKey = _selectedMovieOptionKey;
    if (selectedMovieOptionKey != null &&
        moviesByKey.containsKey(selectedMovieOptionKey)) {
      selectedMovie = moviesByKey[selectedMovieOptionKey];
    }

    final selectedTitle = _normalizedTitle(
      selectedMovie?.title ?? _movieTitleController.text,
    );
    if ((selectedMovie == null || selectedMovie.movieId.trim().isEmpty) &&
        selectedTitle.isNotEmpty) {
      for (final movie in availableMovies) {
        if (_normalizedTitle(movie.title) == selectedTitle) {
          selectedMovie = movie;
          break;
        }
      }
    }

    final movieTitle =
        selectedMovie?.title.trim() ?? _movieTitleController.text.trim();
    if (movieTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn phim từ danh sách.')),
      );
      return;
    }

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập cảm nhận của bạn.')),
      );
      return;
    }

    final cloudinaryService = Provider.of<CloudinaryService>(context, listen: false);
    final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);

    setState(() => _submitting = true);

    try {
      String? uploadedImageUrl;
      final selectedImage = _selectedImage;
      if (selectedImage != null) {
        uploadedImageUrl = await cloudinaryService.uploadImage(
          filePath: selectedImage.path,
          folder: 'cinememo/reviews',
        );
      }

      final editingReview = _editingReview;
      if (editingReview != null) {
        await firestoreService.updateReview(
          reviewId: editingReview.reviewId,
          content: content,
          rating: _rating,
          weather: _weatherSummary,
          location: _locationSummary,
          imageUrl: uploadedImageUrl ?? editingReview.imageUrl,
        );
      } else {
        final selectedMovieId = selectedMovie?.movieId.trim() ?? '';
        final movieId = selectedMovieId.isNotEmpty
            ? selectedMovieId
            : (_prefilledMovieIdFromArgs.isNotEmpty
                  ? _prefilledMovieIdFromArgs
                  : 'manual-entry');
        final review = ReviewModel(
          reviewId: const Uuid().v4(),
          userId: uid,
          userDisplayName: auth.displayName,
          userPhotoUrl: auth.photoUrl,
          movieId: movieId,
          movieTitle: movieTitle,
          rating: _rating,
          content: content,
          weather: _weatherSummary,
          location: _locationSummary,
          imageUrl: uploadedImageUrl,
          createdAt: DateTime.now(),
        );
        await firestoreService.createReview(review);
      }

      if (!mounted) {
        return;
      }

      await reviewProvider.refreshCurrentUserReviewCount();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editingReview != null
                ? 'Đã cập nhật nhật ký thành công.'
                : 'Đã đăng nhật ký thành công.',
          ),
        ),
      );

      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final movieProvider = Provider.of<MovieProvider>(context);
    final availableMovies = _availableMovies(movieProvider);
    final moviesByKey = {
      for (final movie in availableMovies) _movieOptionKey(movie): movie,
    };
    final selectedMovieOptionKey = _selectedMovieOptionKey;
    String? dropdownValue;
    if (selectedMovieOptionKey != null &&
        moviesByKey.containsKey(selectedMovieOptionKey)) {
      dropdownValue = selectedMovieOptionKey;
    } else if (_selectedMovie != null) {
      final selectedTitle = _normalizedTitle(_selectedMovie!.title);
      for (final entry in moviesByKey.entries) {
        if (_normalizedTitle(entry.value.title) == selectedTitle) {
          dropdownValue = entry.key;
          break;
        }
      }
    }

    final movie = dropdownValue != null
        ? moviesByKey[dropdownValue]
        : _selectedMovie;
    final isEditing = _editingReview != null;
    final selectedImage = _selectedImage;
    final selectedImageBytes = _selectedImageBytes;
    final existingImageUrl = (_editingReview?.imageUrl ?? '').trim();
    final hasSelectedImagePreview =
        selectedImage != null && selectedImageBytes != null;
    final hasExistingImagePreview =
        !hasSelectedImagePreview && existingImageUrl.isNotEmpty;
    final staticMapPrimaryUrl = _buildOpenStreetMapTileUrl();
    final staticMapFallbackUrl = _buildYandexStaticMapUrl();

    Widget buildMapLoadingPlaceholder() {
      return const ColoredBox(
        color: Color(0xFFF1F5F9),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    Widget buildMapErrorPlaceholder([
      String message = 'Không tải được ảnh bản đồ',
    ]) {
      return ColoredBox(
        color: const Color(0xFFF1F5F9),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    Widget buildPreviewCard({
      required IconData icon,
      required String title,
      required Widget child,
      Widget? action,
    }) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF0F172A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (action != null) action,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
    }

    Widget buildImagePreviewContent(double previewHeight) {
      Widget media;
      if (hasSelectedImagePreview) {
        media = Image.memory(selectedImageBytes, fit: BoxFit.cover);
      } else if (hasExistingImagePreview) {
        media = Image.network(
          existingImageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const ColoredBox(
              color: Color(0xFFF1F5F9),
              child: Center(
                child: Text(
                  'Không tải được ảnh hiện tại',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ),
            );
          },
        );
      } else {
        media = const ColoredBox(
          color: Color(0xFFF8FAFC),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_camera_back_outlined,
                  color: Color(0xFF94A3B8),
                  size: 24,
                ),
                SizedBox(height: 6),
                Text(
                  'Chưa chọn ảnh',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: previewHeight,
              width: double.infinity,
              child: media,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedImage != null
                ? 'Đã chọn: ${selectedImage.name}'
                : (hasExistingImagePreview
                      ? 'Ảnh hiện tại của nhật ký'
                      : 'Hãy thêm ảnh để nhật ký sinh động hơn'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      );
    }

    Widget buildLocationPreviewContent(double previewHeight) {
      Widget mapWidget;
      if (staticMapPrimaryUrl == null) {
        mapWidget = buildMapErrorPlaceholder('Chưa lấy được vị trí hiện tại.');
      } else {
        mapWidget = Image.network(
          staticMapPrimaryUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return buildMapLoadingPlaceholder();
          },
          errorBuilder: (context, error, stackTrace) {
            if (staticMapFallbackUrl == null) {
              return buildMapErrorPlaceholder();
            }

            return Image.network(
              staticMapFallbackUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, fallbackLoadingProgress) {
                if (fallbackLoadingProgress == null) {
                  return child;
                }
                return buildMapLoadingPlaceholder();
              },
              errorBuilder: (context, fallbackError, fallbackStackTrace) {
                return buildMapErrorPlaceholder(
                  'Không tải được ảnh bản đồ.\nHãy kiểm tra kết nối mạng.',
                );
              },
            );
          },
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: previewHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  mapWidget,
                  const Center(
                    child: Icon(
                      Icons.location_pin,
                      size: 34,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 13,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Vị trí hiện tại',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Map data: OpenStreetMap',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _locationSummary != null
                ? 'Vị trí: $_locationSummary'
                : 'Vị trí: chưa xác định',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          if (_weatherSummary != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Thời tiết: $_weatherSummary',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Sửa nhật ký điện ảnh' : 'Tạo nhật ký điện ảnh',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: dropdownValue,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Chọn phim từ danh sách',
              hintText: availableMovies.isEmpty
                  ? 'Đang tải danh sách phim...'
                  : 'Nhấn để chọn phim',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: availableMovies
                .map(
                  (movieItem) => DropdownMenuItem<String>(
                    value: _movieOptionKey(movieItem),
                    child: Text(
                      movieItem.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: availableMovies.isEmpty
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }

                    final selectedMovie = moviesByKey[value];
                    if (selectedMovie == null) {
                      return;
                    }

                    setState(() {
                      _applySelectedMovie(selectedMovie);
                    });
                  },
          ),
          const SizedBox(height: 10),
          if (dropdownValue == null && availableMovies.isNotEmpty)
            const Text(
              'Chọn phim ở dropdown trước khi đăng nhật ký.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          if (movie != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Movie ID: ${movie.movieId}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          const SizedBox(height: 10),
          RatingStars(
            rating: _rating,
            onRatingChanged: (value) => setState(() => _rating = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Chia sẻ cảm nhận của bạn ...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_a_photo_rounded),
            label: Text(_selectedImage == null ? 'Chọn ảnh' : 'Đổi ảnh'),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth >= 900;
              final previewHeight = useTwoColumns ? 170.0 : 210.0;

              final imageCard = buildPreviewCard(
                icon: Icons.photo_library_rounded,
                title: 'Ảnh đính kèm',
                child: buildImagePreviewContent(previewHeight),
              );

              final locationCard = buildPreviewCard(
                icon: Icons.location_on_rounded,
                title: 'Vị trí check-in',
                action: TextButton.icon(
                  onPressed: _submitting
                      ? null
                      : () {
                          _loadWeatherAndLocation();
                        },
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Làm mới'),
                ),
                child: buildLocationPreviewContent(previewHeight),
              );

              if (useTwoColumns) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: imageCard),
                    const SizedBox(width: 12),
                    Expanded(child: locationCard),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [imageCard, const SizedBox(height: 12), locationCard],
              );
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _submitting
                    ? 'Đang lưu...'
                    : (isEditing ? 'Cập nhật nhật ký' : 'Đăng nhật ký'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
