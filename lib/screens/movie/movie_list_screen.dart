import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/voucher_catalog.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/movie_model.dart';
import '../../providers/movie_provider.dart';
import '../../services/firebase/firebase_firestore_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_routes.dart';
import '../../widgets/common/custom_bottom_nav_bar.dart';
import '../../widgets/layouts/movie_list_grid.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final CarouselSliderController _bannerController = CarouselSliderController();
  final ScrollController _scrollController = ScrollController();
  int _currentBanner = 0;

  static const List<BannerModel> _seedBanners = [
    BannerModel(
      title: 'Chào bạn mới',
      subtitle: 'Giảm 30% vé đầu tiên với mã CINEMEMO30',
      colorA: Color(0xFF114B5F),
      colorB: Color(0xFF1A936F),
      imageUrl:
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=1200&q=80',
    ),
    BannerModel(
      title: 'Deal combo bỏng và nước',
      subtitle: 'Tiết kiệm đến 45K khi đặt kèm vé',
      colorA: Color(0xFF3A2E39),
      colorB: Color(0xFF8A5A44),
      imageUrl:
          'https://images.unsplash.com/photo-1578849278619-e73505e9610f?auto=format&fit=crop&w=1200&q=80',
    ),
    BannerModel(
      title: 'Voucher ngày lễ',
      subtitle: 'Tặng 1 nước ngọt cho vé VIP',
      colorA: Color(0xFF2F3C7E),
      colorB: Color(0xFFF08A5D),
      imageUrl:
          'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?auto=format&fit=crop&w=1200&q=80',
    ),
  ];
  late final List<BannerModel> _banners = List<BannerModel>.from(_seedBanners);

  final List<VoucherOffer> _vouchers = VoucherCatalog.vouchers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final movieProvider = Provider.of<MovieProvider>(context, listen: false);
      if (movieProvider.nowShowing.isEmpty &&
          movieProvider.comingSoon.isEmpty) {
        movieProvider.loadHomeData();
      }
    });
  }

  Future<void> _refreshHomeData() async {
    await Provider.of<MovieProvider>(context, listen: false).loadHomeData();
    if (!mounted) {
      return;
    }

    setState(() {
      if (_banners.length > 1) {
        final first = _banners.removeAt(0);
        _banners.add(first);
      }
      _currentBanner = 0;
    });
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openSupportChat() async {
    if (!mounted) {
      return;
    }

    final movieProvider = Provider.of<MovieProvider>(context, listen: false);
    final suggestedMovies = _buildHeroMovies(
      _collectUniqueMovies(movieProvider),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupportChatBottomSheet(
        suggestedMovies: suggestedMovies,
        voucherOffers: _vouchers,
      ),
    );
  }

  Future<bool> _promptLoginForFavorites() async {
    if (!mounted) {
      return false;
    }

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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _heroBannerHeightFor(double width) {
    if (!kIsWeb) {
      return 188;
    }
    if (width >= 1700) {
      return 300;
    }
    if (width >= 1200) {
      return 260;
    }
    if (width >= 900) {
      return 230;
    }
    return 200;
  }

  int _voucherColumnsForWeb(double width) {
    if (width >= 1700) {
      return 4;
    }
    if (width >= 1200) {
      return 3;
    }
    if (width >= 860) {
      return 2;
    }
    return 1;
  }

  double _voucherCardWidthForWeb({
    required double maxWidth,
    required double spacing,
  }) {
    final columns = _voucherColumnsForWeb(maxWidth);
    final availableWidth = maxWidth - 32;
    final rawWidth = (availableWidth - (columns - 1) * spacing) / columns;
    return rawWidth.clamp(220.0, 480.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final movieProvider = Provider.of<MovieProvider>(context);
    final currentMovies = movieProvider.currentMovies;
    final allMovies = _collectUniqueMovies(movieProvider);
    final heroMovies = _buildHeroMovies(allMovies);
    final heroItems = _buildHeroItems(heroMovies);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final heroBannerHeight = _heroBannerHeightFor(viewportWidth);
    final heroViewportFraction = kIsWeb ? 1.0 : 0.92;
    final heroBannerMargin = kIsWeb ? 0.0 : 6.0;

    return Scaffold(
      extendBodyBehindAppBar: false,
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 0),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _FooterBackToTopButton(onTap: _scrollToTop),
      body: Stack(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF9FBFF), AppColors.scaffold],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _refreshHomeData,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    const SliverToBoxAdapter(child: _TopBar()),
                    SliverToBoxAdapter(
                      child: CarouselSlider.builder(
                        carouselController: _bannerController,
                        itemCount: heroItems.length,
                        options: CarouselOptions(
                          height: heroBannerHeight,
                          autoPlay: true,
                          autoPlayInterval: const Duration(seconds: 4),
                          viewportFraction: heroViewportFraction,
                          onPageChanged: (index, _) {
                            setState(() => _currentBanner = index);
                          },
                        ),
                        itemBuilder: (context, index, _) {
                          final item = heroItems[index];
                          if (item.banner != null) {
                            return _PromoBanner(
                              data: item.banner!,
                              horizontalMargin: heroBannerMargin,
                            );
                          }

                          final movie = item.movie!;
                          return _MovieHeroBanner(
                            movie: movie,
                            horizontalMargin: heroBannerMargin,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.movieDetail,
                                arguments: movie,
                              );
                            },
                            onBook: movie.status == MovieStatus.nowShowing
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
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _BannerDots(
                        count: heroItems.length,
                        activeIndex: _currentBanner,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            const Text(
                              'Voucher ưu đãi',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.voucherList,
                                );
                              },
                              child: const Text('Xem tất cả'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final spacing = kIsWeb ? 12.0 : 10.0;
                          final stripHeight = kIsWeb ? 170.0 : 142.0;
                          final cardWidth = kIsWeb
                              ? _voucherCardWidthForWeb(
                                  maxWidth: constraints.maxWidth,
                                  spacing: spacing,
                                )
                              : 256.0;

                          return SizedBox(
                            height: stripHeight,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: _vouchers.length,
                              separatorBuilder: (_, _) =>
                                  SizedBox(width: spacing),
                              itemBuilder: (context, index) => _VoucherCard(
                                data: _vouchers[index],
                                width: cardWidth,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    SliverAppBar(
                      pinned: true,
                      automaticallyImplyLeading: false,
                      backgroundColor: Theme.of(
                        context,
                      ).scaffoldBackgroundColor,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      toolbarHeight: 72,
                      titleSpacing: 0,
                      title: _MovieSearchBarTile(
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.movieSearch);
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _MovieStatusTabs(
                        tabIndex: movieProvider.tabIndex,
                        onChanged: movieProvider.setTabIndex,
                      ),
                    ),
                    if (movieProvider.isLoading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    if (movieProvider.error != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(
                            movieProvider.error!,
                            style: const TextStyle(color: Color(0xFFB91C1C)),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: MovieListGrid(
                        movies: currentMovies,
                        onTapMovie: (movie) => Navigator.pushNamed(
                          context,
                          AppRoutes.movieDetail,
                          arguments: movie,
                        ),
                        onShareMovie: (movie) => Navigator.pushNamed(
                          context,
                          AppRoutes.createReview,
                          arguments: movie,
                        ),
                        onBookMovie: (movie) {
                          if (movie.status == MovieStatus.nowShowing) {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.showtimeSelection,
                              arguments: {
                                'movie': movie,
                                'movieId': movie.movieId,
                              },
                            );
                          }
                        },
                        isFavoriteMovie: movieProvider.isFavoriteMovie,
                        onToggleFavoriteMovie: (movie) {
                          _handleToggleFavorite(movie);
                        },
                      ),
                    ),
                    if (!movieProvider.isLoading && currentMovies.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
                          child: Text(
                            'Không có dữ liệu phim. Hãy kiểm tra MOVIE_API_BASE_URL hoặc kết nối mạng.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    SliverToBoxAdapter(child: const _CinemaFooter()),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 92,
            child: _FloatingSupportChatButton(onTap: _openSupportChat),
          ),
        ],
      ),
    );
  }

  List<MovieModel> _collectUniqueMovies(MovieProvider provider) {
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

  List<MovieModel> _buildHeroMovies(List<MovieModel> movies) {
    final sorted = [...movies]
      ..sort((a, b) {
        final statusCompare = _statusScore(
          b.status,
        ).compareTo(_statusScore(a.status));
        if (statusCompare != 0) {
          return statusCompare;
        }

        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) {
          return ratingCompare;
        }

        final aDate = a.releaseDate;
        final bDate = b.releaseDate;
        if (aDate != null && bDate != null) {
          return bDate.compareTo(aDate);
        }
        if (aDate != null) {
          return -1;
        }
        if (bDate != null) {
          return 1;
        }
        return 0;
      });

    return sorted.take(4).toList();
  }

  List<_HomeHeroItem> _buildHeroItems(List<MovieModel> heroMovies) {
    final items = <_HomeHeroItem>[
      for (final movie in heroMovies) _HomeHeroItem.movie(movie),
      for (final banner in _banners) _HomeHeroItem.banner(banner),
    ];

    return items;
  }

  int _statusScore(MovieStatus status) {
    return status == MovieStatus.nowShowing ? 2 : 1;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Icon(
                Icons.movie_filter_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CineMemo',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Đặt vé nhanh, lưu kỷ niệm điện ảnh của bạn',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const _TopAccountActions(),
          ],
        ),
      ),
    );
  }
}

class _TopAccountActions extends StatelessWidget {
  const _TopAccountActions();

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final current = localeProvider.locale.languageCode;

    Widget flagButton(String code, String label) {
      final selected = current == code;
      return GestureDetector(
        onTap: () => localeProvider.setLocale(Locale(code)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: selected ? AppColors.primary.withValues(alpha: 0.08) : null,
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        flagButton('vi', 'Vi'),
        const SizedBox(width: 8),
        flagButton('en', 'En'),
        const SizedBox(width: 10),
        Builder(
          builder: (context) {
            final auth = Provider.of<AuthProvider>(context);
            if (!auth.isAuthenticated) {
              Widget authButton({
                required String label,
                required bool filled,
                required VoidCallback onTap,
              }) {
                return GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: filled ? AppColors.primary : Colors.transparent,
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: filled ? Colors.white : AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  authButton(
                    label: 'Đăng nhập',
                    filled: false,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.login,
                        arguments: const {'registerMode': false},
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  authButton(
                    label: 'Đăng ký',
                    filled: true,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.login,
                        arguments: const {'registerMode': true},
                      );
                    },
                  ),
                ],
              );
            }

            final photo = auth.photoUrl.trim();
            return GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.profile);
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.surfaceAlt,
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 18,
                        color: AppColors.textSecondary,
                      )
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }
}

// _TopAuthLink removed (unused)

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.data, this.horizontalMargin = 6});

  final BannerModel data;
  final double horizontalMargin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (data.imageUrl.trim().isNotEmpty)
              CachedNetworkImage(
                imageUrl: data.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    data.colorA.withValues(alpha: 0.92),
                    data.colorB.withValues(alpha: 0.86),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Khuyến mãi',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeroItem {
  const _HomeHeroItem.banner(this.banner) : movie = null;
  const _HomeHeroItem.movie(this.movie) : banner = null;

  final BannerModel? banner;
  final MovieModel? movie;
}

class _MovieHeroBanner extends StatelessWidget {
  const _MovieHeroBanner({
    required this.movie,
    required this.onTap,
    this.horizontalMargin = 6,
    this.onBook,
  });

  final MovieModel movie;
  final VoidCallback onTap;
  final double horizontalMargin;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final imageUrl = movie.backdropUrl.trim().isNotEmpty
        ? movie.backdropUrl.trim()
        : movie.posterUrl.trim();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xBB000000), Color(0x66000000)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          movie.status == MovieStatus.nowShowing
                              ? 'Phim đang hot'
                              : 'Sắp chiếu',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${movie.genre} • ${movie.duration} phút',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: onTap,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white70),
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Chi tiết'),
                          ),
                          const SizedBox(width: 8),
                          if (onBook != null)
                            FilledButton(
                              onPressed: onBook,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Đặt vé'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.data, this.width = 256});

  final VoucherOffer data;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0B1F3A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: data.imageUrl, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xB8000000), Color(0x33000000)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        data.code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.subtitle,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerDots extends StatelessWidget {
  const _BannerDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final isActive = index == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : const Color(0xFFBFD0E6),
              borderRadius: BorderRadius.circular(99),
            ),
          );
        }),
      ),
    );
  }
}

class _MovieStatusTabs extends StatelessWidget {
  const _MovieStatusTabs({required this.tabIndex, required this.onChanged});

  final int tabIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _MovieStatusTabButton(
                    label: 'PHIM SẮP CHIẾU',
                    active: tabIndex == 1,
                    onTap: () => onChanged(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MovieStatusTabButton(
                    label: 'PHIM ĐANG CHIẾU',
                    active: tabIndex == 0,
                    onTap: () => onChanged(0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MovieStatusTabButton extends StatelessWidget {
  const _MovieStatusTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.primary : AppColors.border,
              width: active ? 4 : 1,
            ),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? AppColors.primary : AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _MovieSearchBarTile extends StatelessWidget {
  const _MovieSearchBarTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tìm theo tên phim...',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const List<String> _developmentPlans = [
  'Xây dựng Admin Panel để quản lý suất chiếu, combo, banner trực tiếp trên web/app.',
  'Thêm chức năng đặt vé nhóm, chia sẻ vé cho bạn bè.',
  'Tích hợp thanh toán VNPay ngoài MoMo để đa dạng lựa chọn.',
  'Mở rộng hỗ trợ xác thực tuổi bằng CCCD (nếu cần).',
  'Admin panel thống kê doanh thu theo rạp và khung giờ.',
];

class _CinemaFooter extends StatelessWidget {
  const _CinemaFooter({this.onBackToTop});

  static const Color _background = Color(0xFF0457A8);
  static const Color _mutedText = Color(0xFFD8E6FF);
  static const Color _headline = Color(0xFFFF7CA8);
  final VoidCallback? onBackToTop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontalPadding = width >= 1200
            ? 84.0
            : (width >= 900 ? 40.0 : 20.0);
        final sections = <Widget>[
          _FooterAboutColumn(mutedText: _mutedText, headline: _headline),
          _FooterAppSectionsColumn(mutedText: _mutedText, headline: _headline),
          _FooterContactColumn(mutedText: _mutedText, headline: _headline),
        ];

        return Container(
          width: double.infinity,
          color: _background,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              38,
              horizontalPadding,
              24,
            ),
            child: Column(
              children: [
                if (width >= 1180)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Expanded(
                        flex: 3,
                        child: _FooterAboutColumn(
                          mutedText: _mutedText,
                          headline: _headline,
                        ),
                      ),
                      SizedBox(width: 26),
                      Expanded(
                        flex: 4,
                        child: _FooterAppSectionsColumn(
                          mutedText: _mutedText,
                          headline: _headline,
                        ),
                      ),
                      SizedBox(width: 26),
                      Expanded(
                        flex: 4,
                        child: _FooterContactColumn(
                          mutedText: _mutedText,
                          headline: _headline,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < sections.length; i++) ...[
                        sections[i],
                        if (i < sections.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Divider(color: Color(0x33FFFFFF), height: 1),
                          ),
                      ],
                    ],
                  ),
                const SizedBox(height: 24),
                const Divider(color: Color(0x33FFFFFF), height: 1),
                const SizedBox(height: 16),
                if (width >= 720)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Text(
                          '© 2026 CineMemo. All rights reserved.',
                          style: TextStyle(color: _mutedText, fontSize: 12),
                        ),
                      ),
                      if (onBackToTop != null)
                        _FooterBackToTopButton(onTap: onBackToTop!),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '© 2026 CineMemo. All rights reserved.',
                        style: TextStyle(color: _mutedText, fontSize: 12),
                      ),
                      if (onBackToTop != null) ...[
                        const SizedBox(height: 12),
                        _FooterBackToTopButton(onTap: onBackToTop!),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FooterAboutColumn extends StatelessWidget {
  const _FooterAboutColumn({required this.mutedText, required this.headline});

  final Color mutedText;
  final Color headline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FooterLogoMark(),
        const SizedBox(height: 14),
        _FooterLinkList(
          items: const [
            'Về CineMemo',
            'Hướng dẫn đặt vé',
            'Cách sử dụng mã khuyến mãi',
            'Điều khoản sử dụng',
            'Điều khoản bảo mật',
            'Câu hỏi thường gặp',
          ],
          color: mutedText,
        ),
        const SizedBox(height: 16),
        _FooterTitle(text: 'TÍNH NĂNG CHÍNH', color: headline),
        const SizedBox(height: 10),
        _FooterLinkList(
          items: const [
            'Khám phá phim đang chiếu và sắp chiếu',
            'Đặt ghế theo suất chiếu thời gian thực',
            'Thanh toán MoMo QR hoặc Gateway',
            'Nhật ký xem phim và đánh giá',
            'Lưu phim yêu thích và thống kê cá nhân',
          ],
          color: mutedText,
        ),
      ],
    );
  }
}

class _FooterAppSectionsColumn extends StatelessWidget {
  const _FooterAppSectionsColumn({
    required this.mutedText,
    required this.headline,
  });

  final Color mutedText;
  final Color headline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FooterTitle(text: 'TÍNH NĂNG ĐANG PHÁT TRIỂN', color: headline),
        const SizedBox(height: 10),
        _FooterLinkList(color: mutedText, items: _developmentPlans),
      ],
    );
  }
}

class _FooterContactColumn extends StatelessWidget {
  const _FooterContactColumn({required this.mutedText, required this.headline});

  final Color mutedText;
  final Color headline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FooterTitle(text: 'HỖ TRỢ', color: headline),
        const SizedBox(height: 10),
        const Text(
          'ỨNG DỤNG CINE MEMO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Nền tảng đặt vé, thanh toán và lưu nhật ký trải nghiệm điện ảnh dành cho người dùng Việt Nam.',
          style: TextStyle(color: mutedText, height: 1.45),
        ),
        const SizedBox(height: 8),
        Text(
          'Được xây dựng bằng Flutter, Firebase và tích hợp thông báo lịch chiếu qua FCM.',
          style: TextStyle(color: mutedText, height: 1.45),
        ),
        const SizedBox(height: 14),
        const Text(
          'KÊNH HỖ TRỢ NGƯỜI DÙNG',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Trong app: Tài khoản > Trợ giúp và phản hồi',
          style: TextStyle(color: mutedText),
        ),
        Text(
          'Email kỹ thuật: cinememo.app@gmail.com',
          style: TextStyle(color: mutedText),
        ),
        const SizedBox(height: 12),
        const Text(
          'THANH TOÁN VÀ THÔNG BÁO',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'MoMo: QR cá nhân hoặc gateway sandbox',
          style: TextStyle(color: mutedText),
        ),
        Text(
          'Reminder: FCM trước suất chiếu 30 phút',
          style: TextStyle(color: mutedText),
        ),
        const SizedBox(height: 12),
        const Text(
          'KHU VỰC QUẢN TRỊ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Theo dõi đặt vé, đánh giá và dữ liệu người dùng',
          style: TextStyle(color: mutedText),
        ),
        Text(
          'Tính năng giới hạn theo vai trò Admin',
          style: TextStyle(color: mutedText),
        ),
        const SizedBox(height: 12),
        const Text(
          'KẾT NỐI VỚI CINE MEMO',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            _FooterSocialIcon(icon: Icons.facebook_rounded),
            SizedBox(width: 8),
            _FooterSocialIcon(icon: Icons.play_arrow_rounded),
            SizedBox(width: 8),
            _FooterSocialIcon(icon: Icons.music_note_rounded),
            SizedBox(width: 8),
            _FooterSocialIcon(icon: Icons.camera_alt_rounded),
          ],
        ),
        const SizedBox(height: 14),
        const _FooterCommerceBadge(),
      ],
    );
  }
}

class _FooterTitle extends StatelessWidget {
  const _FooterTitle({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 112,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _FooterLinkList extends StatelessWidget {
  const _FooterLinkList({required this.items, required this.color});

  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '›  $item',
              style: TextStyle(color: color, height: 1.38),
            ),
          ),
      ],
    );
  }
}

class _FooterLogoMark extends StatelessWidget {
  const _FooterLogoMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Icon(Icons.local_movies_rounded, color: Colors.white, size: 38),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Cine',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                height: 0.9,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Memo',
              style: TextStyle(
                color: Color(0xFFD8E6FF),
                fontSize: 22,
                height: 0.9,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Movie Booking App',
              style: TextStyle(
                color: Color(0xFFD8E6FF),
                fontSize: 11,
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FooterSocialIcon extends StatelessWidget {
  const _FooterSocialIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, color: const Color(0xFF0457A8), size: 20),
    );
  }
}

class _FooterCommerceBadge extends StatelessWidget {
  const _FooterCommerceBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x66FFFFFF)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text(
            'CINEMEMO PROJECT\nFLUTTER + FIREBASE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingSupportChatButton extends StatelessWidget {
  const _FloatingSupportChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF155EEF), Color(0xFF0B57D0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B57D0).withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text(
                'Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportChatBottomSheet extends StatefulWidget {
  const _SupportChatBottomSheet({
    required this.suggestedMovies,
    required this.voucherOffers,
  });

  final List<MovieModel> suggestedMovies;
  final List<VoucherOffer> voucherOffers;

  @override
  State<_SupportChatBottomSheet> createState() =>
      _SupportChatBottomSheetState();
}

class _SupportChatBottomSheetState extends State<_SupportChatBottomSheet> {
  // supported theaters list removed (unused)

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  // StreamSubscription<Map<String, dynamic>>? _requestSubscription; // Deprecated: Using Firebase Extension
  StreamSubscription<String?>? _conversationSubscription;
  String? _conversationId;
  int? _pendingAssistantMessageIndex;
  final List<_SupportChatMessage> _messages = [
    const _SupportChatMessage(
      text:
          'Xin chào! Mình là hỗ trợ CineMemo. Bạn cần tư vấn lịch chiếu, thanh toán hay hoàn vé?',
      isUser: false,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _messageScrollController.dispose();
    // _requestSubscription?.cancel(); // Deprecated
    _conversationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(_SupportChatMessage(text: text, isUser: true));
      _messages.add(
        const _SupportChatMessage(
          text: 'Đang gửi yêu cầu đến Gemini... vui lòng chờ.',
          isUser: false,
          isLoading: true,
        ),
      );
      _pendingAssistantMessageIndex = _messages.length - 1;
      _messageController.clear();
    });
    _scrollToBottom();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final firestoreService = Provider.of<FirebaseFirestoreService>(
      context,
      listen: false,
    );

    try {
      // Ensure conversation exists
      if (_conversationId == null) {
        _conversationId = await firestoreService.createAiConversation(
          userId: authProvider.uid ?? 'guest',
        );

        // Start watching generate/{conversationId}/response field
        // Firebase Extension writes AI response here
        _conversationSubscription?.cancel();
        _conversationSubscription = firestoreService
            .watchGenerateResponse(_conversationId!)
            .listen((responseText) {
              if (!mounted || _pendingAssistantMessageIndex == null) return;
              if (responseText == null) return;

              setState(() {
                final index = _pendingAssistantMessageIndex!;
                if (index >= 0 && index < _messages.length) {
                  _messages[index] = _SupportChatMessage(
                    text: responseText.isNotEmpty
                        ? responseText
                        : 'Gemini trả về không hợp lệ. Vui lòng thử lại sau.',
                    isUser: false,
                    isLoading: false,
                  );
                }
                _pendingAssistantMessageIndex = null;
              });
              _scrollToBottom();
            });
      }

      // Append user message to conversation history
      await firestoreService.addAiMessage(
        conversationId: _conversationId!,
        role: 'user',
        text: text,
        userId: authProvider.uid ?? 'guest',
      );

      // Build conversation context and create a generate request document.
      // Firebase Extension will process this document and write response.
      final prompt = _buildGeneratePrompt(text);
      final requestId = await firestoreService.createGenerateRequest(
        prompt: prompt,
        userId: authProvider.uid ?? 'guest',
        conversationId: _conversationId,
      );

      // Watch the generated response for this request.
      _conversationSubscription?.cancel();
      _conversationSubscription = firestoreService
          .watchGenerateResponse(requestId)
          .listen((responseText) {
            if (!mounted || _pendingAssistantMessageIndex == null) return;
            if (responseText == null) return;

            setState(() {
              final index = _pendingAssistantMessageIndex!;
              if (index >= 0 && index < _messages.length) {
                _messages[index] = _SupportChatMessage(
                  text: responseText.isNotEmpty
                      ? responseText
                      : 'Gemini trả về không hợp lệ. Vui lòng thử lại sau.',
                  isUser: false,
                  isLoading: false,
                );
              }
              _pendingAssistantMessageIndex = null;
            });
            _scrollToBottom();
          });
    } catch (error, stack) {
      debugPrint('Failed to send AI message: $error');
      debugPrint(stack.toString());
      if (!mounted) {
        return;
      }
      final isStateErr = error is StateError;
      final errorText = error?.toString() ?? 'Không xác định';
      final userMessage = isStateErr
          ? 'Không thể kết nối tới Firebase. Vui lòng kiểm tra cấu hình và kết nối.'
          : 'Lỗi gửi yêu cầu Gemini: $errorText';

      setState(() {
        final index = _pendingAssistantMessageIndex;
        if (index != null && index >= 0 && index < _messages.length) {
          _messages[index] = _SupportChatMessage(
            text: userMessage,
            isUser: false,
            isLoading: false,
            isError: true,
          );
        }
        _pendingAssistantMessageIndex = null;
      });
    }
  }

  // ignore: unused_element
  String _buildGeneratePrompt(String userInput, {int maxTitles = 50}) {
    // Lấy danh sách phim từ provider và xử lý an toàn
    final movieProvider = Provider.of<MovieProvider>(context, listen: false);
    final movies = [...movieProvider.nowShowing, ...movieProvider.comingSoon];

    final titles = movies
        .map((m) => m.title.replaceAll('\n', ' ').trim())
        .where((t) => t.isNotEmpty)
        .take(maxTitles)
        .toList();

    final encoded = jsonEncode(titles);
    final truncatedNote = movies.length > maxTitles
        ? ' (chỉ hiển thị ${titles.length} phim đầu tiên)'
        : '';

    final movieListText = titles.isEmpty ? '[]' : '$encoded$truncatedNote';

    // Giữ prompt ngắn gọn và có chỉ dẫn rõ ràng
    return '''Bạn là trợ lý ảo của CineMemo. Hãy tuân thủ các quy tắc sau:
1. Dữ liệu phim của bạn chỉ giới hạn trong danh sách sau: $movieListText.
2. Nếu người dùng hỏi về phim không nằm trong danh sách này, hãy trả lời: "Rất tiếc, phim này hiện không có trong danh sách chiếu của CineMemo."
3. Tuyệt đối không được tự bịa ra phim hay lịch chiếu dựa trên kiến thức bên ngoài.
4. Trả lời ngắn gọn, lịch sự và bằng tiếng Việt.

Thông tin người dùng: môi trường ứng dụng CineMemo, có thể tư vấn lịch chiếu, voucher, thanh toán, review và tính năng đặt vé.

Yêu cầu của người dùng: $userInput''';
  }

  // Deprecated: Using Firebase Extension now (generate collection)
  // void _watchRequest(String requestId) {
  //   _requestSubscription?.cancel();
  //   _requestSubscription =
  //       Provider.of<FirebaseFirestoreService>(
  //         context,
  //         listen: false,
  //       ).watchAiRequest(requestId).listen((data) {
  //         debugPrint('[DEBUG] watchAiRequest received data: $data');
  //         if (!mounted || _pendingAssistantMessageIndex == null) {
  //           debugPrint(
  //             '[DEBUG] watchAiRequest: not mounted or no pending index',
  //           );
  //           return;
  //         }

  //         final responseText = _extractAiResponse(data);
  //         final status = (data['status'] as String?)?.trim().toLowerCase();
  //         final isFailed = status == 'failed';
  //         debugPrint(
  //           '[DEBUG] watchAiRequest: responseText=$responseText, status=$status, isFailed=$isFailed',
  //         );

  //         if (responseText == null && status == 'pending') {
  //           debugPrint(
  //             '[DEBUG] watchAiRequest: still pending, not updating UI',
  //           );
  //           return;
  //         }

  //         debugPrint('[DEBUG] watchAiRequest: updating UI with response');
  //         setState(() {
  //           final index = _pendingAssistantMessageIndex!;
  //           if (index >= 0 && index < _messages.length) {
  //             _messages[index] = _SupportChatMessage(
  //               text:
  //                   responseText ??
  //                   'Gemini trả về không hợp lệ. Vui lòng thử lại sau.',
  //               isUser: false,
  //               isLoading: false,
  //               isError: isFailed,
  //             );
  //           }
  //           _pendingAssistantMessageIndex = null;
  //         });
  //         _scrollToBottom();
  //       });
  // }

  // Deprecated: Using Firebase Extension now
  // String? _extractAiResponse(Map<String, dynamic> data) {
  //   return data['translatedText'] as String? ??
  //       data['response'] as String? ??
  //       data['output'] as String? ??
  //       data['assistantOutput'] as String? ??
  //       data['result'] as String?;
  // }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageScrollController.hasClients) {
        return;
      }
      _messageScrollController.animateTo(
        _messageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;
    final insets = MediaQuery.viewInsetsOf(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 520),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    gradient: LinearGradient(
                      colors: [Color(0xFF155EEF), Color(0xFF0B57D0)],
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0x22FFFFFF),
                        child: Icon(
                          Icons.support_agent_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'CineMemo hỗ trợ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                        tooltip: 'Đóng',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _messageScrollController,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final bubbleColor = message.isUser
                          ? const Color(0xFF155EEF)
                          : const Color(0xFFF1F5F9);
                      final textColor = message.isUser
                          ? Colors.white
                          : const Color(0xFF1E293B);

                      return Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: message.isLoading
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        message.text,
                                        style: TextStyle(
                                          color: textColor,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  message.text,
                                  style: TextStyle(
                                    color: textColor,
                                    height: 1.35,
                                    fontStyle: message.isError
                                        ? FontStyle.italic
                                        : null,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Nhập tin nhắn...',
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF155EEF),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _sendMessage,
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(12),
                          backgroundColor: const Color(0xFF155EEF),
                        ),
                        child: const Icon(Icons.send_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportChatMessage {
  const _SupportChatMessage({
    required this.text,
    required this.isUser,
    this.isLoading = false,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isLoading;
  final bool isError;
}

class _FooterBackToTopButton extends StatelessWidget {
  const _FooterBackToTopButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0x14000000),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0x80FFFFFF), width: 1.2),
        ),
        child: const Icon(
          Icons.keyboard_arrow_up_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
