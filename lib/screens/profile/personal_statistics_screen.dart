import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/review_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase/firebase_firestore_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/common/custom_bottom_nav_bar.dart';

enum _StatisticType { reviews, theaters, watchedMovies }

enum _TimeRange { week, month, quarter, year, all }

class PersonalStatisticsScreen extends StatefulWidget {
  const PersonalStatisticsScreen({super.key});

  @override
  State<PersonalStatisticsScreen> createState() =>
      _PersonalStatisticsScreenState();
}

class _PersonalStatisticsScreenState extends State<PersonalStatisticsScreen> {
  static const Duration _usedAfterShowtime = Duration(hours: 2, minutes: 30);

  static const Map<String, String> _theaterNameFallback = {
    't01': 'CineMemo Landmark 81',
    't02': 'CineMemo Thủ Đức',
    't03': 'CineMemo Quận 7',
    't04': 'CineMemo Hoàn Kiếm',
    't05': 'CineMemo Cầu Giấy',
    't06': 'CineMemo Hà Đông',
  };

  _StatisticType _statisticType = _StatisticType.reviews;
  _TimeRange _timeRange = _TimeRange.month;

  DateTime? _toDateTime(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    return null;
  }

  DateTime? _extractShowStartAt(Map<String, dynamic> booking) {
    final startAtRaw = booking['showStartAt'] ?? booking['showtimeStartAt'];
    final startAt = _toDateTime(startAtRaw);
    if (startAt != null) {
      return startAt;
    }

    final showDate = _toDateTime(booking['showDate']);
    final showtimeLabel = (booking['showtimeLabel'] as String? ?? '').trim();
    if (showDate != null) {
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(showtimeLabel);
      if (timeMatch != null) {
        final hour = int.tryParse(timeMatch.group(1) ?? '0') ?? 0;
        final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
        return DateTime(
          showDate.year,
          showDate.month,
          showDate.day,
          hour,
          minute,
        );
      }
    }

    final showtimeId = (booking['showtimeId'] as String? ?? '').trim();
    final match = RegExp(r'(\d{8})-(\d{2}):(\d{2})$').firstMatch(showtimeId);
    if (match == null) {
      return null;
    }

    final dateRaw = match.group(1)!;
    final year = int.tryParse(dateRaw.substring(0, 4));
    final month = int.tryParse(dateRaw.substring(4, 6));
    final day = int.tryParse(dateRaw.substring(6, 8));
    final hour = int.tryParse(match.group(2)!);
    final minute = int.tryParse(match.group(3)!);

    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    return DateTime(year, month, day, hour, minute);
  }

  bool _isUsedBooking(Map<String, dynamic> booking) {
    final isUsedRaw = booking['isUsed'];
    if (isUsedRaw is bool) {
      return isUsedRaw;
    }

    final usedAtRaw = booking['usedAt'] ?? booking['checkedInAt'];
    if (usedAtRaw is Timestamp || usedAtRaw is DateTime) {
      return true;
    }
    if (usedAtRaw is String && usedAtRaw.trim().isNotEmpty) {
      return true;
    }

    final status = (booking['status'] as String? ?? '').trim().toLowerCase();
    const usedStatuses = {
      'used',
      'checked_in',
      'checkedin',
      'checked-in',
      'redeemed',
      'consumed',
      'completed',
      'done',
    };
    if (usedStatuses.contains(status)) {
      return true;
    }

    final showStartAt = _extractShowStartAt(booking);
    if (showStartAt == null) {
      return false;
    }

    return DateTime.now().isAfter(showStartAt.add(_usedAfterShowtime));
  }

  DateTime? _bookingMoment(Map<String, dynamic> booking) {
    return _extractShowStartAt(booking) ??
        _toDateTime(booking['usedAt']) ??
        _toDateTime(booking['checkedInAt']) ??
        _toDateTime(booking['transactionAt']) ??
        _toDateTime(booking['createdAt']);
  }

  DateTime? _rangeStart(DateTime now) {
    switch (_timeRange) {
      case _TimeRange.week:
        return now.subtract(const Duration(days: 7));
      case _TimeRange.month:
        return now.subtract(const Duration(days: 30));
      case _TimeRange.quarter:
        return now.subtract(const Duration(days: 90));
      case _TimeRange.year:
        return now.subtract(const Duration(days: 365));
      case _TimeRange.all:
        return null;
    }
  }

  bool _isAfterRange(DateTime? value, DateTime? rangeStart) {
    if (rangeStart == null) {
      return true;
    }
    if (value == null) {
      return false;
    }
    return !value.isBefore(rangeStart);
  }

  String _movieTitleFrom(Map<String, dynamic> booking) {
    final title = (booking['movieTitle'] as String? ?? '').trim();
    if (title.isNotEmpty) {
      return title;
    }
    return 'Phim đã đặt';
  }

  String _theaterIdFrom(Map<String, dynamic> booking) {
    final raw = (booking['showtimeId'] as String? ?? '').trim();
    if (raw.isEmpty) {
      return '';
    }
    return raw.split('-').first;
  }

  String _theaterNameFrom(Map<String, dynamic> booking) {
    final direct = (booking['theaterName'] as String? ?? '').trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    final theaterId = _theaterIdFrom(booking);
    return _theaterNameFallback[theaterId] ?? 'Chưa rõ rạp';
  }

  String _timeRangeLabel(_TimeRange value) {
    switch (value) {
      case _TimeRange.week:
        return '1 tuần';
      case _TimeRange.month:
        return '1 tháng';
      case _TimeRange.quarter:
        return '3 tháng';
      case _TimeRange.year:
        return '1 năm';
      case _TimeRange.all:
        return 'Tất cả';
    }
  }

  String _statTypeLabel(_StatisticType value) {
    switch (value) {
      case _StatisticType.reviews:
        return 'Đánh giá';
      case _StatisticType.theaters:
        return 'Rạp hay xem';
      case _StatisticType.watchedMovies:
        return 'Phim đã xem';
    }
  }

  _StatisticsBundle _buildBundle({
    required List<ReviewModel> reviews,
    required List<Map<String, dynamic>> bookings,
  }) {
    final now = DateTime.now();
    final rangeStart = _rangeStart(now);

    final filteredReviews = reviews
        .where((review) => _isAfterRange(review.createdAt, rangeStart))
        .toList();

    final watchedBookings = bookings.where(_isUsedBooking).where((booking) {
      final moment = _bookingMoment(booking);
      return _isAfterRange(moment, rangeStart);
    }).toList();

    final theaterCounts = <String, int>{};
    final movieCounts = <String, int>{};
    for (final booking in watchedBookings) {
      final theater = _theaterNameFrom(booking);
      final movie = _movieTitleFrom(booking);
      theaterCounts[theater] = (theaterCounts[theater] ?? 0) + 1;
      movieCounts[movie] = (movieCounts[movie] ?? 0) + 1;
    }

    final theaters =
        theaterCounts.entries
            .map((entry) => _CountEntry(label: entry.key, count: entry.value))
            .toList()
          ..sort((a, b) {
            final byCount = b.count.compareTo(a.count);
            if (byCount != 0) {
              return byCount;
            }
            return a.label.toLowerCase().compareTo(b.label.toLowerCase());
          });

    final movies =
        movieCounts.entries
            .map((entry) => _CountEntry(label: entry.key, count: entry.value))
            .toList()
          ..sort((a, b) {
            final byCount = b.count.compareTo(a.count);
            if (byCount != 0) {
              return byCount;
            }
            return a.label.toLowerCase().compareTo(b.label.toLowerCase());
          });

    final ratingBuckets = List<int>.filled(5, 0);
    double totalRating = 0;
    for (final review in filteredReviews) {
      totalRating += review.rating;
      final rounded = review.rating.round();
      if (rounded >= 1 && rounded <= 5) {
        ratingBuckets[rounded - 1] += 1;
      }
    }

    final averageRating = filteredReviews.isEmpty
        ? 0.0
        : totalRating / filteredReviews.length;

    return _StatisticsBundle(
      reviews: filteredReviews,
      watchedBookings: watchedBookings,
      theaters: theaters,
      movies: movies,
      ratingBuckets: ratingBuckets,
      averageRating: averageRating,
      uniqueMovieCount: movies.length,
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    Color iconColor = const Color(0xFF0F172A),
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(_StatisticsBundle bundle) {
    final totalBuckets = bundle.ratingBuckets.fold<int>(
      0,
      (total, bucketCount) => total + bucketCount,
    );
    final maxBucket = bundle.ratingBuckets.isEmpty
        ? 0
        : bundle.ratingBuckets.reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _summaryCard(
              icon: Icons.rate_review_rounded,
              title: 'Đánh giá trong kỳ',
              value: '${bundle.reviews.length}',
              iconColor: const Color(0xFF0EA5E9),
            ),
            const SizedBox(width: 8),
            _summaryCard(
              icon: Icons.star_rate_rounded,
              title: 'Điểm trung bình',
              value: bundle.averageRating.toStringAsFixed(1),
              iconColor: const Color(0xFFF59E0B),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (totalBuckets == 0)
          _buildEmptyState(
            'Chưa có dữ liệu đánh giá trong khoảng thời gian này.',
          )
        else
          Container(
            height: 260,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Phân bố điểm đánh giá',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: 1,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0xFFE2E8F0),
                          strokeWidth: 1,
                        ),
                      ),
                      maxY: math.max(1, maxBucket + 1).toDouble(),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 1,
                            getTitlesWidget: (value, _) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              final star = value.toInt() + 1;
                              if (star < 1 || star > 5) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '$star★',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: bundle.ratingBuckets.asMap().entries.map((
                        entry,
                      ) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.toDouble(),
                              width: 18,
                              borderRadius: BorderRadius.circular(5),
                              color: const Color(0xFF0F172A),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTheaterSection(_StatisticsBundle bundle) {
    if (bundle.theaters.isEmpty) {
      return _buildEmptyState(
        'Chưa có suất xem nào trong khoảng thời gian này.',
      );
    }

    final topTheaters = bundle.theaters.take(6).toList();
    final totalViews = topTheaters.fold<int>(
      0,
      (total, item) => total + item.count,
    );

    const palette = <Color>[
      Color(0xFF0F172A),
      Color(0xFF0EA5E9),
      Color(0xFF22C55E),
      Color(0xFFF97316),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _summaryCard(
              icon: Icons.local_movies_rounded,
              title: 'Tổng suất đã xem',
              value: '${bundle.watchedBookings.length}',
              iconColor: const Color(0xFF0EA5E9),
            ),
            const SizedBox(width: 8),
            _summaryCard(
              icon: Icons.location_city_rounded,
              title: 'Rạp xem nhiều nhất',
              value: topTheaters.first.label,
              iconColor: const Color(0xFF22C55E),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tỷ trọng theo rạp',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 210,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 42,
                    sectionsSpace: 3,
                    sections: topTheaters.asMap().entries.map((entry) {
                      final ratio = entry.value.count / totalViews;
                      final percent = (ratio * 100).round();
                      return PieChartSectionData(
                        color: palette[entry.key % palette.length],
                        value: entry.value.count.toDouble(),
                        radius: 66,
                        title: percent >= 8 ? '$percent%' : '',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...topTheaters.asMap().entries.map((entry) {
                final color = palette[entry.key % palette.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${entry.value.count} lượt'),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWatchedMoviesSection(_StatisticsBundle bundle) {
    if (bundle.movies.isEmpty) {
      return _buildEmptyState(
        'Chưa có phim đã xem trong khoảng thời gian này.',
      );
    }

    final topMovies = bundle.movies.take(6).toList();
    final maxCount = topMovies.map((item) => item.count).reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _summaryCard(
              icon: Icons.movie_filter_rounded,
              title: 'Số lần đi xem',
              value: '${bundle.watchedBookings.length}',
              iconColor: const Color(0xFF6366F1),
            ),
            const SizedBox(width: 8),
            _summaryCard(
              icon: Icons.confirmation_number_rounded,
              title: 'Số phim khác nhau',
              value: '${bundle.uniqueMovieCount}',
              iconColor: const Color(0xFF0EA5E9),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top phim xem nhiều nhất',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: Color(0xFFE2E8F0),
                        strokeWidth: 1,
                      ),
                    ),
                    maxY: math.max(1, maxCount + 1).toDouble(),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (value, _) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) {
                            final index = value.toInt();
                            if (index < 0 || index >= topMovies.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: topMovies.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.count.toDouble(),
                            width: 18,
                            borderRadius: BorderRadius.circular(5),
                            color: const Color(0xFF334155),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...topMovies.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key + 1}.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${entry.value.count} lượt'),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF64748B))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thống kê cá nhân')),
        body: Center(
          child: SizedBox(
            width: 220,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Đăng nhập'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        bottomNavigationBar: const CustomBottomNavBar(currentIndex: 3),
      );
    }

    final uid = (auth.uid ?? '').trim();
    final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê cá nhân')),
      body: StreamBuilder<List<ReviewModel>>(
        stream: firestoreService.watchUserReviews(uid, limit: 600),
        builder: (context, reviewSnapshot) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: firestoreService.watchUserBookings(uid),
            builder: (context, bookingSnapshot) {
              if (reviewSnapshot.hasError || bookingSnapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildEmptyState(
                      'Không tải được thống kê lúc này. Vui lòng thử lại sau.',
                    ),
                  ],
                );
              }

              final reviews = reviewSnapshot.data ?? const <ReviewModel>[];
              final bookings =
                  bookingSnapshot.data ?? const <Map<String, dynamic>>[];

              final loading =
                  (reviewSnapshot.connectionState == ConnectionState.waiting &&
                      !reviewSnapshot.hasData) ||
                  (bookingSnapshot.connectionState == ConnectionState.waiting &&
                      !bookingSnapshot.hasData);

              if (loading) {
                return const Center(child: CircularProgressIndicator());
              }

              final bundle = _buildBundle(reviews: reviews, bookings: bookings);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<_StatisticType>(
                          initialValue: _statisticType,
                          decoration: InputDecoration(
                            labelText: 'Loại thống kê',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: _StatisticType.values
                              .map(
                                (type) => DropdownMenuItem<_StatisticType>(
                                  value: type,
                                  child: Text(_statTypeLabel(type)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _statisticType = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<_TimeRange>(
                          initialValue: _timeRange,
                          decoration: InputDecoration(
                            labelText: 'Thời gian',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: _TimeRange.values
                              .map(
                                (range) => DropdownMenuItem<_TimeRange>(
                                  value: range,
                                  child: Text(_timeRangeLabel(range)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _timeRange = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bộ lọc: ${_statTypeLabel(_statisticType)} • ${_timeRangeLabel(_timeRange)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_statisticType == _StatisticType.reviews)
                    _buildReviewSection(bundle)
                  else if (_statisticType == _StatisticType.theaters)
                    _buildTheaterSection(bundle)
                  else
                    _buildWatchedMoviesSection(bundle),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 3),
    );
  }
}

class _CountEntry {
  const _CountEntry({required this.label, required this.count});

  final String label;
  final int count;
}

class _StatisticsBundle {
  const _StatisticsBundle({
    required this.reviews,
    required this.watchedBookings,
    required this.theaters,
    required this.movies,
    required this.ratingBuckets,
    required this.averageRating,
    required this.uniqueMovieCount,
  });

  final List<ReviewModel> reviews;
  final List<Map<String, dynamic>> watchedBookings;
  final List<_CountEntry> theaters;
  final List<_CountEntry> movies;
  final List<int> ratingBuckets;
  final double averageRating;
  final int uniqueMovieCount;
}
