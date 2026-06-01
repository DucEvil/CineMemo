import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/firebase/firebase_firestore_service.dart';
import '../../utils/constants.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isSeeding = false;
  String? _seedMessage;

  Future<void> _seedFirestoreData() async {
    final firestore = Provider.of<FirebaseFirestoreService>(context, listen: false);
    final userId = Provider.of<AuthProvider>(context, listen: false).uid ?? 'seed-system';

    setState(() {
      _isSeeding = true;
      _seedMessage = null;
    });

    try {
      final now = DateTime.now();

      final movies = <Map<String, dynamic>>[
        {
          'movieId': 'm1',
          'title': 'Lật Mặt: Tấm Vé Định Mệnh',
          'genre': 'Hành động, Tâm lý',
          'cast': 'Lý Hải, Khả Ngân',
          'duration': 128,
          'ageLabel': '16+',
          'status': 'nowShowing',
          'rating': 4.4,
          'description': 'Bộ phim hành động tâm lý với nhiều pha xoay chuyển.',
          'posterUrl':
              'https://img.ophim.live/uploads/movies/lat-mat-7-poster.jpg',
          'trailerUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
        {
          'movieId': 'm2',
          'title': 'Mai',
          'genre': 'Tình cảm, Hài hước',
          'cast': 'Trấn Thành, Phương Anh Đào',
          'duration': 131,
          'ageLabel': '13+',
          'status': 'nowShowing',
          'rating': 4.1,
          'description':
              'Phim tình cảm Việt Nam với nhiều chi tiết đời thường.',
          'posterUrl': 'https://img.ophim.live/uploads/movies/mai-poster.jpg',
          'trailerUrl': 'https://www.youtube.com/watch?v=oHg5SJYRHA0',
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
        {
          'movieId': 'm3',
          'title': 'Quỷ Cẩu',
          'genre': 'Kinh dị, Bí ẩn',
          'cast': 'Thu Trang, Quang Tuấn',
          'duration': 112,
          'ageLabel': '18+',
          'status': 'comingSoon',
          'rating': 0,
          'description': 'Phim kinh dị Việt sắp khởi chiếu.',
          'posterUrl':
              'https://img.ophim.live/uploads/movies/quy-cau-poster.jpg',
          'trailerUrl': '',
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
        {
          'movieId': 'm4',
          'title': 'Nhà Bà Nữ',
          'genre': 'Tâm lý, Gia đình',
          'cast': 'Lê Giang, Trấn Thành, Uyển Ân',
          'duration': 133,
          'ageLabel': '16+',
          'status': 'nowShowing',
          'rating': 4.0,
          'description':
              'Câu chuyện gia đình với nhiều xung đột và hành trình hòa giải.',
          'posterUrl':
              'https://images.unsplash.com/photo-1594909122845-11baa439b7bf',
          'trailerUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
        {
          'movieId': 'm5',
          'title': 'Đào, Phở và Piano',
          'genre': 'Lịch sử, Chiến tranh',
          'cast': 'Cao Thị Thùy Anh, Đoàn Quốc Đam',
          'duration': 100,
          'ageLabel': '13+',
          'status': 'nowShowing',
          'rating': 4.2,
          'description':
              'Bộ phim lịch sử về Hà Nội trong bối cảnh chiến tranh và âm nhạc.',
          'posterUrl':
              'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba',
          'trailerUrl': 'https://www.youtube.com/watch?v=oHg5SJYRHA0',
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
        {
          'movieId': 'm6',
          'title': 'Người Vợ Cuối Cùng',
          'genre': 'Chính kịch, Cổ trang',
          'cast': 'Kaity Nguyễn, Quốc Huy',
          'duration': 118,
          'ageLabel': '16+',
          'status': 'comingSoon',
          'rating': 0,
          'description':
              'Dự án cổ trang sắp khởi chiếu với bối cảnh Nam Bộ xưa.',
          'posterUrl':
              'https://images.unsplash.com/photo-1478720568477-152d9b164e26',
          'trailerUrl': '',
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
      ];

      final theaters = <Map<String, dynamic>>[
        {
          'theaterId': 't01',
          'name': 'CineMemo Landmark 81',
          'address': '720A Điện Biên Phủ, Bình Thạnh, TP.HCM',
          'city': 'Ho Chi Minh',
          'lat': 10.7949,
          'lng': 106.7219,
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
        {
          'theaterId': 't02',
          'name': 'CineMemo Thủ Đức',
          'address': 'Võ Văn Ngân, TP. Thủ Đức, TP.HCM',
          'city': 'Ho Chi Minh',
          'lat': 10.8506,
          'lng': 106.7719,
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
      ];

      final showtimes = <Map<String, dynamic>>[
        {
          'showtimeId': 's01',
          'movieId': 'm1',
          'theaterId': 't01',
          'hallName': 'Hall 1',
          'startTime': now.add(const Duration(hours: 4)).toIso8601String(),
          'price': 75000,
          'availableSeats': 80,
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
        {
          'showtimeId': 's02',
          'movieId': 'm2',
          'theaterId': 't02',
          'hallName': 'Hall 2',
          'startTime': now.add(const Duration(hours: 6)).toIso8601String(),
          'price': 85000,
          'availableSeats': 64,
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
        {
          'showtimeId': 's03',
          'movieId': 'm4',
          'theaterId': 't01',
          'hallName': 'Hall 3',
          'startTime': now.add(const Duration(hours: 8)).toIso8601String(),
          'price': 79000,
          'availableSeats': 72,
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
        {
          'showtimeId': 's04',
          'movieId': 'm5',
          'theaterId': 't02',
          'hallName': 'Hall 1',
          'startTime': now.add(const Duration(hours: 10)).toIso8601String(),
          'price': 73000,
          'availableSeats': 70,
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
        {
          'showtimeId': 's05',
          'movieId': 'm1',
          'theaterId': 't02',
          'hallName': 'Hall 4',
          'startTime': now.add(const Duration(hours: 12)).toIso8601String(),
          'price': 88000,
          'availableSeats': 68,
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
      ];

      final banners = <Map<String, dynamic>>[
        {
          'bannerId': 'b01',
          'title': 'Khuyến mãi cuối tuần',
          'subtitle': 'Giảm 20% vé khi đặt qua app',
          'imageUrl':
              'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba',
          'isActive': true,
          'priority': 1,
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
        {
          'bannerId': 'b02',
          'title': 'Combo bỏng nước',
          'subtitle': 'Thêm combo chỉ từ 45K',
          'imageUrl':
              'https://images.unsplash.com/photo-1578849278619-e73505e9610f',
          'isActive': true,
          'priority': 2,
          'updatedBy': userId,
          'updatedAt': now.toIso8601String(),
        },
      ];

      for (final movie in movies) {
        await firestore.upsertDocument(
          collectionPath: AppConstants.moviesCollection,
          documentId: movie['movieId'] as String,
          data: movie,
        );
      }

      for (final theater in theaters) {
        await firestore.upsertDocument(
          collectionPath: AppConstants.theatersCollection,
          documentId: theater['theaterId'] as String,
          data: theater,
        );
      }

      for (final showtime in showtimes) {
        await firestore.upsertDocument(
          collectionPath: AppConstants.showtimesCollection,
          documentId: showtime['showtimeId'] as String,
          data: showtime,
        );
      }

      for (final banner in banners) {
        await firestore.upsertDocument(
          collectionPath: AppConstants.bannersCollection,
          documentId: banner['bannerId'] as String,
          data: banner,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _seedMessage =
            'Seed dữ liệu thành công: movies/theaters/showtimes/banners.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().contains('permission-denied')
          ? 'Bị từ chối quyền ghi. Bạn cần quyền quản trị hoặc tạm mở quy tắc ghi cho bộ dữ liệu mẫu.'
          : 'Seed thất bại: $error';

      setState(() {
        _seedMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSeeding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bảng điều khiển quản trị')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Công cụ khởi tạo dữ liệu Firestore cho giai đoạn thử nghiệm ứng dụng.',
              style: TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSeeding ? null : _seedFirestoreData,
                icon: _isSeeding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  _isSeeding ? 'Đang seed dữ liệu...' : 'Seed dữ liệu mẫu',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_seedMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  _seedMessage!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
