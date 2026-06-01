import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/review_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/review_provider.dart';
import '../../services/firebase/firebase_firestore_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/common/custom_bottom_nav_bar.dart';
import '../../widgets/common/fullscreen_image_viewer.dart';

class MyReviewScreen extends StatefulWidget {
  const MyReviewScreen({super.key});

  @override
  State<MyReviewScreen> createState() => _MyReviewScreenState();
}

class _MyReviewScreenState extends State<MyReviewScreen> {
  final Set<String> _deletingReviewIds = <String>{};

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatDateTime(DateTime value) {
    return '${_twoDigits(value.hour)}:${_twoDigits(value.minute)} ${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year}';
  }

  String _shareMessage(ReviewModel review) {
    final buffer = StringBuffer()
      ..writeln('Nhật ký điện ảnh từ CineMemo')
      ..writeln('Phim: ${review.movieTitle}')
      ..writeln('Danh giá: ${review.rating.toStringAsFixed(1)}/5');

    if (review.content.trim().isNotEmpty) {
      buffer
        ..writeln('')
        ..writeln('Cảm nhận:')
        ..writeln(review.content.trim());
    }

    if ((review.weather ?? '').trim().isNotEmpty) {
      buffer.writeln('Thời tiết: ${review.weather!.trim()}');
    }

    if ((review.location ?? '').trim().isNotEmpty) {
      buffer.writeln('Vị trí: ${review.location!.trim()}');
    }

    buffer.writeln('Thời gian: ${_formatDateTime(review.createdAt)}');
    return buffer.toString().trim();
  }

  Future<void> _shareReview(ReviewModel review) async {
    try {
      await Share.share(
        _shareMessage(review),
        subject: 'Nhật ký phim: ${review.movieTitle}',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở chia sẻ lúc này.')),
      );
    }
  }

  Future<void> _editReview(ReviewModel review) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.createReview,
      arguments: {'review': review},
    );
  }

  Future<bool> _confirmDeleteReview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa nhật ký?'),
          content: const Text(
            'Bạn có chắc chắn muốn xóa nhật ký này không? Hành động này không thể hoàn tác.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _deleteReview(ReviewModel review) async {
    final shouldDelete = await _confirmDeleteReview();
    if (!shouldDelete || !mounted) {
      return;
    }

    setState(() => _deletingReviewIds.add(review.reviewId));

    try {
      await Provider.of<FirebaseFirestoreService>(context, listen: false).deleteReview(
        review.reviewId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa nhật ký.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa nhật ký. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingReviewIds.remove(review.reviewId));
      }
    }
  }

  Future<void> _refresh() async {
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
    final isDeleting = _deletingReviewIds.contains(review.reviewId);
    final imageUrl = (review.imageUrl ?? '').trim();
    final weather = (review.weather ?? '').trim();
    final location = (review.location ?? '').trim();

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
              Expanded(
                child: Text(
                  review.movieTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildRatingBadge(review.rating),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatDateTime(review.createdAt),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            review.content,
            style: const TextStyle(color: Color(0xFF334155), height: 1.4),
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
                              'Không tải được ảnh',
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isDeleting ? null : () => _shareReview(review),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text(
                    'Chia sẻ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isDeleting ? null : () => _editReview(review),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text(
                    'Sửa',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isDeleting ? null : () => _deleteReview(review),
                  icon: const Icon(Icons.delete_rounded, size: 16),
                  label: const Text(
                    'Xóa',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
          if (isDeleting)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final uid = (auth.uid ?? '').trim();

    if (uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nhật ký của tôi')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vui lòng đăng nhập để quản lý nhật ký của bạn.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.login),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Đăng nhập'),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const CustomBottomNavBar(currentIndex: 2),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký của tôi')),
      body: StreamBuilder<List<ReviewModel>>(
        stream: Provider.of<FirebaseFirestoreService>(context, listen: false).watchUserReviews(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Không thể tải nhật ký của bạn: ${snapshot.error}',
                  textAlign: TextAlign.center,
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
                      'Bạn chưa có nhật ký nào.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.createReview),
                      icon: const Icon(Icons.add_comment_rounded),
                      label: const Text('Tạo nhật ký mới'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
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
        onPressed: () => Navigator.pushNamed(context, AppRoutes.createReview),
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
