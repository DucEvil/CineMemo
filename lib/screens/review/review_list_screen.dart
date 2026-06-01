import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/review_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/review_provider.dart';
import '../../services/firebase/firebase_firestore_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/common/fullscreen_image_viewer.dart';
import '../../widgets/common/custom_bottom_nav_bar.dart';

class ReviewListScreen extends StatefulWidget {
  const ReviewListScreen({super.key});

  @override
  State<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends State<ReviewListScreen> {
  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatDateTime(DateTime value) {
    return '${_twoDigits(value.hour)}:${_twoDigits(value.minute)} ${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year}';
  }

  String _buildInitials(String displayName) {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'U';
    }
    if (parts.length == 1) {
      final value = parts.first;
      return value.substring(0, value.length > 1 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _shareMessage(ReviewModel review) {
    final content = review.content.trim();
    final weather = (review.weather ?? '').trim();
    final location = (review.location ?? '').trim();

    final buffer = StringBuffer()
      ..writeln('Nhật ký điện ảnh từ CineMemo')
      ..writeln('Tác giả: ${review.userDisplayName}')
      ..writeln('Phim: ${review.movieTitle}')
      ..writeln('Đánh giá: ${review.rating.toStringAsFixed(1)}/5');

    if (content.isNotEmpty) {
      buffer
        ..writeln('')
        ..writeln('Cảm nhận:')
        ..writeln(content);
    }

    if (weather.isNotEmpty) {
      buffer.writeln('Thời tiết: $weather');
    }

    if (location.isNotEmpty) {
      buffer.writeln('Vị trí: $location');
    }

    buffer.writeln('Thời gian: ${_formatDateTime(review.createdAt)}');

    return buffer.toString().trim();
  }

  Future<void> _shareReview(ReviewModel review) async {
    final message = _shareMessage(review);
    final movieTitle = review.movieTitle;

    try {
      await Share.share(message, subject: 'Nhật ký phim: $movieTitle');
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở chia sẻ lúc này.')),
      );
    }
  }

  Future<void> _openCreateReview() async {
    final uid = (Provider.of<AuthProvider>(context, listen: false).uid ?? '').trim();
    if (uid.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để tạo nhật ký.')),
      );
      await Navigator.pushNamed(context, AppRoutes.login);
      return;
    }

    await Navigator.pushNamed(context, AppRoutes.createReview);
  }

  Future<void> _openMyReviews() async {
    await Navigator.pushNamed(context, AppRoutes.myReviews);
  }

  Future<void> _refreshFeed() async {
    await Provider.of<ReviewProvider>(context, listen: false).refreshCurrentUserReviewCount();
  }

  Widget _buildRatingBadge(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
          const SizedBox(width: 4),
          Text(
            '${rating.toStringAsFixed(1)}/5',
            style: const TextStyle(
              color: Color(0xFFB45309),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorAvatar(ReviewModel review) {
    final userPhotoUrl = (review.userPhotoUrl ?? '').trim();
    if (userPhotoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          userPhotoUrl,
          width: 30,
          height: 30,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _authorFallbackAvatar(review.userDisplayName);
          },
        ),
      );
    }

    return _authorFallbackAvatar(review.userDisplayName);
  }

  Widget _authorFallbackAvatar(String displayName) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        _buildInitials(displayName),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
          fontSize: 11,
        ),
      ),
    );
  }

  IconData _weatherIconFor(String weatherText) {
    final value = weatherText.toLowerCase();
    if (RegExp(r'mua|rain|drizzle|storm|thunder').hasMatch(value)) {
      return Icons.thunderstorm_rounded;
    }
    if (RegExp(r'nang|sun|clear|hot').hasMatch(value)) {
      return Icons.wb_sunny_rounded;
    }
    if (RegExp(r'may|cloud|overcast').hasMatch(value)) {
      return Icons.cloud_rounded;
    }
    if (RegExp(r'gio|wind').hasMatch(value)) {
      return Icons.air_rounded;
    }
    if (RegExp(r'suong|fog|mist|haze').hasMatch(value)) {
      return Icons.blur_on_rounded;
    }
    if (RegExp(r'tuyet|snow').hasMatch(value)) {
      return Icons.ac_unit_rounded;
    }
    return Icons.wb_cloudy_rounded;
  }

  Color _weatherIconColorFor(String weatherText) {
    final value = weatherText.toLowerCase();
    if (RegExp(r'mua|rain|drizzle|storm|thunder').hasMatch(value)) {
      return const Color(0xFF2563EB);
    }
    if (RegExp(r'nang|sun|clear|hot').hasMatch(value)) {
      return const Color(0xFFEAB308);
    }
    if (RegExp(r'may|cloud|overcast').hasMatch(value)) {
      return const Color(0xFF475569);
    }
    if (RegExp(r'gio|wind').hasMatch(value)) {
      return const Color(0xFF0D9488);
    }
    if (RegExp(r'suong|fog|mist|haze').hasMatch(value)) {
      return const Color(0xFF64748B);
    }
    if (RegExp(r'tuyet|snow').hasMatch(value)) {
      return const Color(0xFF0284C7);
    }
    return const Color(0xFF475569);
  }

  Widget _buildReviewCard(ReviewModel review) {
    final weather = (review.weather ?? '').trim();
    final location = (review.location ?? '').trim();
    final imageUrl = (review.imageUrl ?? '').trim();

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAuthorAvatar(review),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userDisplayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.movieTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildRatingBadge(review.rating),
                  const SizedBox(height: 6),
                  Text(
                    _formatDateTime(review.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (review.content.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                review.content.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF334155), height: 1.4),
              ),
            ),
          if (imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  FullscreenImageViewer.show(context, imageUrls: [imageUrl]);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Image.network(
                        imageUrl,
                        height: 170,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 120,
                            color: const Color(0xFFF1F5F9),
                            alignment: Alignment.center,
                            child: const Text(
                              'Không thể tải ảnh',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          );
                        },
                      ),
                      const Positioned(
                        right: 8,
                        bottom: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0x73000000),
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.zoom_in_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (weather.isNotEmpty || location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (weather.isNotEmpty)
                    _MetaChip(
                      icon: _weatherIconFor(weather),
                      label: weather,
                      iconColor: _weatherIconColorFor(weather),
                    ),
                  if (location.isNotEmpty)
                    _MetaChip(
                      icon: Icons.location_on_outlined,
                      label: location,
                      iconColor: const Color(0xFF2563EB),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _shareReview(review),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Chia sẻ nhật ký'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhật ký điện ảnh'),
        actions: [
          TextButton.icon(
            onPressed: _openMyReviews,
            icon: const Icon(Icons.person_rounded, size: 18),
            label: const Text('Nhật ký của tôi'),
          ),
        ],
      ),
      body: StreamBuilder<List<ReviewModel>>(
        stream: firestoreService.watchReviews(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Không thể tải danh sách nhật ký.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _refreshFeed,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thu lai'),
                    ),
                  ],
                ),
              ),
            );
          }

          final reviews = snapshot.data ?? const <ReviewModel>[];

          if (reviews.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Chưa có nhật ký nào trong cộng đồng.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _openCreateReview,
                      icon: const Icon(Icons.add_comment_rounded),
                      label: const Text('Tạo nhật ký mới'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshFeed,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reviews.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildReviewCard(reviews[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateReview,
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Thêm nhật ký'),
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 2),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.iconColor = const Color(0xFF475569),
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF334155), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
