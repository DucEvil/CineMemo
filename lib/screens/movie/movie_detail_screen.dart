import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../models/movie_model.dart';
import '../../providers/movie_provider.dart';
import '../../utils/app_routes.dart';
import '../../widgets/common/fullscreen_image_viewer.dart';
import '../../widgets/common/inline_youtube_player.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, this.movie});

  final MovieModel? movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final CarouselSliderController _galleryController =
      CarouselSliderController();
  static const double _defaultTrailerAspectRatio = 16 / 9;

  MovieModel? _movie;
  YoutubePlayerController? _youtubeController;
  String _activeTrailerUrl = '';
  String _lastGalleryKey = '';
  bool _loadingDetail = false;
  String? _detailError;
  int _galleryIndex = 0;
  final Map<String, double> _imageAspectRatios = <String, double>{};

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    _syncTrailerController(_movie?.trailerUrl ?? '');
    _loadMovieDetail();
  }

  @override
  void didUpdateWidget(covariant MovieDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie?.movieId != widget.movie?.movieId) {
      _movie = widget.movie;
      _galleryIndex = 0;
      _detailError = null;
      _syncTrailerController(_movie?.trailerUrl ?? '');
      _loadMovieDetail();
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  Future<void> _loadMovieDetail() async {
    final seedMovie = _movie;
    if (seedMovie == null || seedMovie.movieId.trim().isEmpty) {
      return;
    }

    setState(() {
      _loadingDetail = true;
      _detailError = null;
    });

    try {
      final detail = await Provider.of<MovieProvider>(
        context,
        listen: false,
      ).loadMovieDetail(seedMovie);
      if (!mounted) {
        return;
      }
      setState(() {
        _movie = detail;
        _syncTrailerController(detail.trailerUrl);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _detailError = 'Không tải được thông tin phim. Thử lại sau.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDetail = false;
        });
      }
    }
  }

  void _syncTrailerController(String trailerUrl) {
    final normalized = trailerUrl.trim();
    if (_activeTrailerUrl == normalized) {
      return;
    }

    _activeTrailerUrl = normalized;
    final oldController = _youtubeController;

    if (kIsWeb) {
      _youtubeController = null;
      oldController?.dispose();
      return;
    }

    final youtubeId = _extractYoutubeId(normalized);

    if (youtubeId == null) {
      _youtubeController = null;
    } else {
      _youtubeController = YoutubePlayerController(
        initialVideoId: youtubeId,
        flags: YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: false,
        ),
      );
    }

    oldController?.dispose();
  }

  List<String> _buildImageGallery(MovieModel movie) {
    final posterUrl = movie.posterUrl.trim();
    final backdropUrl = movie.backdropUrl.trim();
    final imageGallery = <String>[];
    final seenImages = <String>{};

    void addImage(String raw) {
      final value = _sanitizeDetailImageUrl(raw.trim());
      if (value.isEmpty ||
          !_isRenderableImageUrl(value) ||
          !seenImages.add(value)) {
        return;
      }
      imageGallery.add(value);
    }

    addImage(posterUrl);
    for (final image in movie.galleryUrls) {
      addImage(image);
    }
    addImage(backdropUrl);

    return imageGallery;
  }

  String _sanitizeDetailImageUrl(String rawUrl) {
    if (rawUrl.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return rawUrl;
    }

    final host = uri.host.toLowerCase();
    final path = uri.path;
    if (host.contains('img.ophim.live') &&
        path.toLowerCase().startsWith('/movies/')) {
      return uri.replace(path: '/uploads$path').toString();
    }

    return rawUrl;
  }

  bool _isRenderableImageUrl(String url) {
    final lower = url.toLowerCase();
    if (_hasImageFileExtension(lower)) {
      return true;
    }

    if (lower.contains('/image/upload/')) {
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

  Future<void> _warmUpImageAspectRatios(List<String> imageUrls) async {
    final missing = imageUrls
        .where((url) => !_imageAspectRatios.containsKey(url))
        .toList();
    if (missing.isEmpty) {
      return;
    }

    final updates = <String, double>{};
    for (final imageUrl in missing) {
      final ratio = await _resolveImageAspectRatio(imageUrl);
      if (ratio != null && ratio > 0) {
        updates[imageUrl] = ratio;
      }
    }

    if (!mounted || updates.isEmpty) {
      return;
    }

    setState(() {
      _imageAspectRatios.addAll(updates);
    });
  }

  Future<double?> _resolveImageAspectRatio(String imageUrl) async {
    final stream = NetworkImage(imageUrl).resolve(const ImageConfiguration());
    final completer = Completer<double?>();
    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (imageInfo, _) {
        stream.removeListener(listener);
        final width = imageInfo.image.width.toDouble();
        final height = imageInfo.image.height.toDouble();
        if (!completer.isCompleted) {
          completer.complete(height == 0 ? null : width / height);
        }
      },
      onError: (_, __) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    stream.addListener(listener);
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        stream.removeListener(listener);
        return null;
      },
    );
  }

  double _mediaAspectRatioFor(_DetailMediaItem mediaItem, String posterUrl) {
    if (mediaItem.isTrailer) {
      return _defaultTrailerAspectRatio;
    }

    final imageUrl = mediaItem.imageUrl!;
    final known = _imageAspectRatios[imageUrl];
    if (known != null && known > 0) {
      return known;
    }

    if (posterUrl.isNotEmpty && imageUrl == posterUrl) {
      return 2 / 3;
    }

    return _defaultTrailerAspectRatio;
  }

  double _galleryHeightFor({
    required double availableWidth,
    required double aspectRatio,
    required double viewportHeight,
  }) {
    final minHeight = kIsWeb ? 260.0 : 220.0;
    final maxHeight = (viewportHeight * (kIsWeb ? 0.72 : 0.58))
        .clamp(minHeight, 620.0)
        .toDouble();
    return (availableWidth / aspectRatio)
        .clamp(minHeight, maxHeight)
        .toDouble();
  }

  double _contentWidthForWeb(double width) {
    if (width >= 1700) {
      return 1380;
    }
    if (width >= 1300) {
      return 1160;
    }
    return width;
  }

  String? _extractYoutubeId(String trailerUrl) {
    final source = trailerUrl.trim();
    if (source.isEmpty) {
      return null;
    }

    final directId = RegExp(r'^[A-Za-z0-9_-]{11}$');
    if (directId.hasMatch(source)) {
      return source;
    }

    final normalized = source.startsWith('//') ? 'https:$source' : source;
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return null;
    }

    final host = uri.host.toLowerCase();
    if (host.contains('youtu.be')) {
      if (uri.pathSegments.isEmpty) {
        return null;
      }
      final id = uri.pathSegments.first.trim();
      return directId.hasMatch(id) ? id : null;
    }

    if (host.contains('youtube.com') || host.contains('youtube-nocookie.com')) {
      final queryId = uri.queryParameters['v']?.trim();
      if (queryId != null && directId.hasMatch(queryId)) {
        return queryId;
      }

      final segments = uri.pathSegments;

      final embedIndex = segments.indexOf('embed');
      if (embedIndex >= 0 && embedIndex + 1 < segments.length) {
        final id = segments[embedIndex + 1].trim();
        if (directId.hasMatch(id)) {
          return id;
        }
      }

      final shortsIndex = segments.indexOf('shorts');
      if (shortsIndex >= 0 && shortsIndex + 1 < segments.length) {
        final id = segments[shortsIndex + 1].trim();
        if (directId.hasMatch(id)) {
          return id;
        }
      }

      final liveIndex = segments.indexOf('live');
      if (liveIndex >= 0 && liveIndex + 1 < segments.length) {
        final id = segments[liveIndex + 1].trim();
        if (directId.hasMatch(id)) {
          return id;
        }
      }
    }

    return YoutubePlayer.convertUrlToId(normalized);
  }

  Future<void> _openTrailerInApp(String trailerUrl) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final uri = Uri.tryParse(trailerUrl);
    if (uri == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Link trailer không hợp lệ.')),
      );
      return;
    }

    var launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!launched) {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (!launched) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Không mở được trailer. Thử lại sau.')),
      );
    }
  }

  void _pauseTrailerPlayback() {
    try {
      _youtubeController?.pause();
    } catch (_) {
      // Ignore pause failures from platform-specific player states.
    }
  }

  void _goToSlide({required int index, required int totalItems}) {
    if (index < 0 || index >= totalItems || index == _galleryIndex) {
      return;
    }

    if (_galleryIndex == 0) {
      _pauseTrailerPlayback();
    }

    setState(() => _galleryIndex = index);
    _galleryController.animateToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final movie = _movie;
    if (movie == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết phim')),
        body: const Center(
          child: Text(
            'Không tìm thấy thông tin phim. Hãy mở từ danh sách phim.',
          ),
        ),
      );
    }

    final posterUrl = movie.posterUrl.trim();
    final imageGallery = _buildImageGallery(movie);

    final galleryKey = imageGallery.join('|');
    if (galleryKey != _lastGalleryKey) {
      _lastGalleryKey = galleryKey;
      unawaited(_warmUpImageAspectRatios(imageGallery));
    }

    final trailerUrl = movie.trailerUrl.trim();
    final trailerYoutubeId = _extractYoutubeId(trailerUrl);
    final trailerThumbnailUrl = trailerYoutubeId == null
        ? ''
        : 'https://img.youtube.com/vi/$trailerYoutubeId/hqdefault.jpg';
    final youtubeController = _youtubeController;
    final showEmbeddedTrailer =
        !kIsWeb && trailerUrl.isNotEmpty && youtubeController != null;
    final mediaItems = <_DetailMediaItem>[
      if (trailerUrl.isNotEmpty) _DetailMediaItem.trailer(trailerUrl),
      ...imageGallery.map(_DetailMediaItem.image),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết phim')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final activeIndex = mediaItems.isEmpty
              ? 0
              : _galleryIndex.clamp(0, mediaItems.length - 1);
          final activeMedia = mediaItems.isEmpty
              ? null
              : mediaItems[activeIndex];
          final activeAspectRatio = activeMedia == null
              ? _defaultTrailerAspectRatio
              : _mediaAspectRatioFor(activeMedia, posterUrl);
          final galleryHeight = _galleryHeightFor(
            availableWidth: constraints.maxWidth,
            aspectRatio: activeAspectRatio,
            viewportHeight: MediaQuery.sizeOf(context).height,
          );

          final content = ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (mediaItems.isEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: galleryHeight,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F4C81), Color(0xFF58A6FF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.local_movies_rounded,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    CarouselSlider.builder(
                      carouselController: _galleryController,
                      itemCount: mediaItems.length,
                      options: CarouselOptions(
                        height: galleryHeight,
                        viewportFraction: 1,
                        enableInfiniteScroll: mediaItems.length > 1,
                        onPageChanged: (index, _) {
                          setState(() => _galleryIndex = index);
                        },
                      ),
                      itemBuilder: (context, index, _) {
                        final mediaItem = mediaItems[index];
                        if (mediaItem.isTrailer) {
                          return _TrailerSlide(
                            trailerUrl: mediaItem.trailerUrl!,
                            trailerYoutubeId: trailerYoutubeId,
                            trailerThumbnailUrl: trailerThumbnailUrl,
                            showEmbeddedTrailer: showEmbeddedTrailer,
                            isActive: index == activeIndex,
                            youtubeController: youtubeController,
                            onOpenTrailer: () {
                              _openTrailerInApp(mediaItem.trailerUrl!);
                            },
                          );
                        }

                        final imageUrl = mediaItem.imageUrl!;
                        final isPosterImage =
                            posterUrl.isNotEmpty && imageUrl == posterUrl;
                        final imageIndexInGallery = imageGallery.indexOf(
                          imageUrl,
                        );

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: imageIndexInGallery < 0
                              ? null
                              : () {
                                  FullscreenImageViewer.show(
                                    context,
                                    imageUrls: imageGallery,
                                    initialIndex: imageIndexInGallery,
                                  );
                                },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: ColoredBox(
                              color: const Color(0xFF0B1220),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: isPosterImage
                                        ? BoxFit.contain
                                        : BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (context, url) => SizedBox(
                                      height: galleryHeight,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          height: galleryHeight,
                                          color: const Color(0xFFE2E8F0),
                                          child: const Center(
                                            child: Icon(
                                              Icons.broken_image_rounded,
                                            ),
                                          ),
                                        ),
                                  ),
                                  const Positioned(
                                    right: 12,
                                    bottom: 12,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color(0x80000000),
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(999),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(
                                          Icons.zoom_in_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (mediaItems.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(mediaItems.length, (index) {
                            final active = index == activeIndex;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(99),
                                onTap: () {
                                  _goToSlide(
                                    index: index,
                                    totalItems: mediaItems.length,
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: active ? 18 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? const Color(0xFF0C1A2B)
                                        : const Color(0xFFCBD5E1),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 14),
              if (_loadingDetail)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              if (_detailError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _detailError!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 12,
                    ),
                  ),
                ),
              Text(
                movie.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(label: movie.genre),
                  _MetaChip(label: '${movie.duration} phút'),
                  _MetaChip(label: movie.ageLabel),
                  _MetaChip(
                    label: movie.status == MovieStatus.nowShowing
                        ? 'Đang chiếu'
                        : 'Sắp chiếu',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (movie.description.isNotEmpty)
                Text(
                  movie.description,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    height: 1.45,
                  ),
                ),
              if (movie.cast.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Diễn viên: ${movie.cast}',
                  style: const TextStyle(color: Color(0xFF334155)),
                ),
              ],
              const SizedBox(height: 18),
              if (trailerUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _openTrailerInApp(trailerUrl),
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: Text(
                    kIsWeb
                        ? 'Mở trailer trên trình duyệt'
                        : 'Xem trailer trong ứng dụng',
                  ),
                ),
              if (trailerUrl.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Phim này chưa có link trailer chính thức.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.createReview,
                          arguments: movie,
                        );
                      },
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Chia sẻ nhật ký'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: movie.status == MovieStatus.nowShowing
                          ? () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.showtimeSelection,
                                arguments: {
                                  'movie': movie,
                                  'movieId': movie.movieId,
                                },
                              );
                            }
                          : null,
                      icon: const Icon(Icons.local_activity_rounded),
                      label: const Text('Đặt vé ngay'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          );

          if (!kIsWeb) {
            return content;
          }

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: _contentWidthForWeb(constraints.maxWidth),
              child: content,
            ),
          );
        },
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DetailMediaItem {
  const _DetailMediaItem.image(this.imageUrl) : trailerUrl = null;
  const _DetailMediaItem.trailer(this.trailerUrl) : imageUrl = null;

  final String? imageUrl;
  final String? trailerUrl;

  bool get isTrailer => trailerUrl != null;
}

class _TrailerSlide extends StatefulWidget {
  const _TrailerSlide({
    required this.trailerUrl,
    required this.trailerYoutubeId,
    required this.trailerThumbnailUrl,
    required this.showEmbeddedTrailer,
    required this.isActive,
    required this.youtubeController,
    required this.onOpenTrailer,
  });

  final String trailerUrl;
  final String? trailerYoutubeId;
  final String trailerThumbnailUrl;
  final bool showEmbeddedTrailer;
  final bool isActive;
  final YoutubePlayerController? youtubeController;
  final VoidCallback onOpenTrailer;

  @override
  State<_TrailerSlide> createState() => _TrailerSlideState();
}

class _TrailerSlideState extends State<_TrailerSlide> {
  bool _playInlineWeb = false;

  @override
  void didUpdateWidget(covariant _TrailerSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trailerUrl != widget.trailerUrl ||
        (oldWidget.isActive && !widget.isActive)) {
      _playInlineWeb = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showEmbeddedTrailer && widget.youtubeController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: YoutubePlayer(
          controller: widget.youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: const Color(0xFF0C1A2B),
          progressColors: const ProgressBarColors(
            playedColor: Color(0xFF0C1A2B),
            handleColor: Color(0xFF2563EB),
            backgroundColor: Color(0xFFCBD5E1),
            bufferedColor: Color(0xFF94A3B8),
          ),
          bottomActions: const [
            CurrentPosition(),
            SizedBox(width: 8),
            ProgressBar(isExpanded: true),
            SizedBox(width: 8),
            RemainingDuration(),
            PlaybackSpeedButton(),
            FullScreenButton(),
          ],
        ),
      );
    }

    if (kIsWeb && _playInlineWeb && widget.trailerYoutubeId != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: InlineYoutubePlayer(videoId: widget.trailerYoutubeId!),
      );
    }

    final canPlayInlineOnWeb = kIsWeb && widget.trailerYoutubeId != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.trailerThumbnailUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.trailerThumbnailUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  const ColoredBox(color: Color(0xFF0F172A)),
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x6B000000), Color(0x9E000000)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: IconButton.filledTonal(
              onPressed: () {
                if (canPlayInlineOnWeb) {
                  setState(() {
                    _playInlineWeb = true;
                  });
                  return;
                }
                widget.onOpenTrailer();
              },
              icon: const Icon(Icons.play_arrow_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F172A),
                iconSize: 42,
                padding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const Positioned(left: 14, top: 12, child: _TrailerBadge()),
        ],
      ),
    );
  }
}

class _TrailerBadge extends StatelessWidget {
  const _TrailerBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          'Trailer',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
