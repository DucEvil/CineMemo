import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../models/movie_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/movie_provider.dart';
import '../../services/location/location_service.dart';
import '../../utils/app_routes.dart';

class _TheaterOption {
  const _TheaterOption({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.showtimes,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> showtimes;
}

class ShowtimeSelectionScreen extends StatefulWidget {
  const ShowtimeSelectionScreen({super.key, this.movie});

  final MovieModel? movie;

  @override
  State<ShowtimeSelectionScreen> createState() =>
      _ShowtimeSelectionScreenState();
}

class _ShowtimeSelectionScreenState extends State<ShowtimeSelectionScreen> {
  static const double _defaultLat = 10.7769;
  static const double _defaultLng = 106.7009;
  static const Duration _showtimeCloseAfterStart = Duration(minutes: 5);
  static const Duration _clockRefreshInterval = Duration(seconds: 15);

  static const _theaters = [
    _TheaterOption(
      id: 't01',
      name: 'CineMemo Landmark 81',
      address: 'Bình Thạnh, TP.HCM',
      latitude: 10.7949,
      longitude: 106.7219,
      showtimes: ['13:30', '19:20'],
    ),
    _TheaterOption(
      id: 't02',
      name: 'CineMemo Thủ Đức',
      address: 'Võ Văn Ngân, TP. Thủ Đức',
      latitude: 10.8506,
      longitude: 106.7719,
      showtimes: ['15:00', '20:10'],
    ),
    _TheaterOption(
      id: 't03',
      name: 'CineMemo Quận 7',
      address: 'Nguyễn Hữu Thọ, Quận 7',
      latitude: 10.7327,
      longitude: 106.7214,
      showtimes: ['12:40', '18:40'],
    ),
    _TheaterOption(
      id: 't04',
      name: 'CineMemo Hoàn Kiếm',
      address: 'Tràng Tiền, Hoàn Kiếm, Hà Nội',
      latitude: 21.0257,
      longitude: 105.8540,
      showtimes: ['14:00', '19:00', '21:15'],
    ),
    _TheaterOption(
      id: 't05',
      name: 'CineMemo Cầu Giấy',
      address: 'Trần Thái Tông, Cầu Giấy, Hà Nội',
      latitude: 21.0368,
      longitude: 105.7908,
      showtimes: ['13:45', '18:20', '20:40'],
    ),
    _TheaterOption(
      id: 't06',
      name: 'CineMemo Hà Đông',
      address: 'Tố Hữu, Hà Đông, Hà Nội',
      latitude: 20.9725,
      longitude: 105.7669,
      showtimes: ['12:20', '17:10', '20:00'],
    ),
  ];

  Map<String, double> _distanceByTheater = const {};
  String? _locationHint;
  bool _resolvingLocation = false;
  late final List<DateTime> _availableDates;
  DateTime? _selectedDate;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _availableDates = _buildAvailableDates();
    _selectedDate = _availableDates.first;
    _resolveDistances(requestPermission: true);
    _clockTimer = Timer.periodic(_clockRefreshInterval, (_) {
      if (!mounted) {
        return;
      }
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  List<DateTime> _buildAvailableDates({int days = 7}) {
    final today = _dateOnly(DateTime.now());
    return List.generate(days, (index) => today.add(Duration(days: index)));
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _weekdayLabel(DateTime value) {
    const weekDays = ['Th 2', 'Th 3', 'Th 4', 'Th 5', 'Th 6', 'Th 7', 'CN'];
    return weekDays[value.weekday - 1];
  }

  String _relativeDateLabel(DateTime value) {
    final today = _dateOnly(_now);
    if (_isSameDay(value, today)) {
      return 'Hôm nay';
    }
    if (_isSameDay(value, today.add(const Duration(days: 1)))) {
      return 'Ngày mai';
    }
    return _weekdayLabel(value);
  }

  String _dateChipLabel(DateTime value) {
    return '${_relativeDateLabel(value)} ${_twoDigits(value.day)}/${_twoDigits(value.month)}';
  }

  String _showDateLabel(DateTime value) {
    return '${_relativeDateLabel(value)} ${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year}';
  }

  String _showDateKey(DateTime value) {
    return '${value.year}${_twoDigits(value.month)}${_twoDigits(value.day)}';
  }

  List<String> _showtimesForDate(_TheaterOption theater, DateTime date) {
    final result = <String>{...theater.showtimes};
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    if (isWeekend) {
      result.add('21:40');
    }

    final ordered = result.toList()..sort(_compareTimeLabel);
    return ordered.where((timeLabel) {
      final showStartAt = _showtimeDateTime(date, timeLabel);
      if (showStartAt == null) {
        return false;
      }
      return _isShowtimeBookable(showStartAt);
    }).toList();
  }

  int _compareTimeLabel(String a, String b) {
    return _timeLabelToMinutes(a).compareTo(_timeLabelToMinutes(b));
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

  DateTime? _showtimeDateTime(DateTime date, String timeLabel) {
    final minutes = _timeLabelToMinutes(timeLabel);
    if (minutes < 0 || minutes >= 24 * 60) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  bool _isShowtimeBookable(DateTime showStartAt) {
    final closeAt = showStartAt.add(_showtimeCloseAfterStart);
    return _now.isBefore(closeAt);
  }

  Future<void> _resolveDistances({required bool requestPermission}) async {
    if (_resolvingLocation) {
      return;
    }

    setState(() => _resolvingLocation = true);
    final locationService = Provider.of<LocationService>(context, listen: false);

    try {
      final serviceEnabled = await locationService.isServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }
        setState(() {
          _distanceByTheater = const {};
          _locationHint =
              'Vị trí đang tắt. Vui lòng bật GPS để sắp xếp rạp gần bạn.';
        });
        return;
      }

      var permission = await locationService.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await locationService.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) {
          return;
        }
        setState(() {
          _distanceByTheater = const {};
          _locationHint =
              'Chưa cấp quyền vị trí. Bấm "Bật vị trí" để cấp quyền và sắp xếp rạp theo khoảng cách.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
        setState(() {
          _distanceByTheater = const {};
          _locationHint =
              'Quyền vị trí đã bị từ chối vĩnh viễn. Bấm "Bật vị trí" để mở cài đặt ứng dụng.';
        });
        return;
      }

      final position =
          await locationService.getCurrentPosition() ??
          await locationService.getLastKnownPosition();
      if (!mounted) {
        return;
      }

      if (position == null) {
        _updateDistances(
          locationService: locationService,
          latitude: _defaultLat,
          longitude: _defaultLng,
          hint:
              'Chưa lấy được GPS hiện tại. Đang dùng vị trí mặc định TP.HCM để gợi ý rạp gần bạn.',
        );
        return;
      }

      _updateDistances(
        locationService: locationService,
        latitude: position.latitude,
        longitude: position.longitude,
        hint: null,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _updateDistances(
        locationService: locationService,
        latitude: _defaultLat,
        longitude: _defaultLng,
        hint:
            'Không lấy được GPS hiện tại. Đang dùng vị trí mặc định TP.HCM để gợi ý rạp gần bạn.',
      );
    } finally {
      if (mounted) {
        setState(() => _resolvingLocation = false);
      }
    }
  }

  void _updateDistances({
    required LocationService locationService,
    required double latitude,
    required double longitude,
    required String? hint,
  }) {
    final result = <String, double>{};
    for (final theater in _theaters) {
      result[theater.id] = locationService.distanceInKm(
        startLat: latitude,
        startLng: longitude,
        endLat: theater.latitude,
        endLng: theater.longitude,
      );
    }

    setState(() {
      _distanceByTheater = result;
      _locationHint = hint;
    });
  }

  Future<void> _enableLocation() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final serviceEnabled = await locationService.isServiceEnabled();
    if (!serviceEnabled) {
      await locationService.openLocationSettings();
    } else {
      final permission = await locationService.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        await locationService.openAppSettings();
      }
    }

    if (!mounted) {
      return;
    }
    await _resolveDistances(requestPermission: true);
  }

  MovieModel? _resolveMovieArgument() {
    if (widget.movie != null) {
      return widget.movie;
    }

    final movieProvider = Provider.of<MovieProvider>(context, listen: false);
    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is MovieModel) {
      return arguments;
    }

    if (arguments is Map) {
      final movieFromMap = arguments['movie'];
      if (movieFromMap is MovieModel) {
        return movieFromMap;
      }

      final movieId = arguments['movieId'];
      if (movieId is String && movieId.trim().isNotEmpty) {
        return movieProvider.getMovieById(movieId.trim());
      }
    }

    if (arguments is String && arguments.trim().isNotEmpty) {
      return movieProvider.getMovieById(arguments.trim());
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final movie = _resolveMovieArgument();
    if (movie == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chọn suất chiếu')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Không tìm thấy thông tin phim để đặt vé.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.movieList,
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Về trang chủ'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sortedTheaters = [..._theaters]
      ..sort((a, b) {
        final da = _distanceByTheater[a.id] ?? 999999;
        final db = _distanceByTheater[b.id] ?? 999999;
        return da.compareTo(db);
      });
    final selectedDate = _selectedDate ?? _availableDates.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Rạp và suất chiếu')),
      body: Column(
        children: [
          if (_resolvingLocation || _locationHint != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _resolvingLocation
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Đang lấy vị trí để sắp xếp rạp gần bạn...',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(
                          Icons.location_off_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationHint ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: _enableLocation,
                          child: const Text('Bật vị trí'),
                        ),
                      ],
                    ),
            ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn ngày chiếu',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _availableDates
                        .map(
                          (date) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              selected: _isSameDay(date, selectedDate),
                              label: Text(_dateChipLabel(date)),
                              onSelected: (_) {
                                setState(() => _selectedDate = date);
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sortedTheaters.length,
              separatorBuilder: (context, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final theater = sortedTheaters[index];
                final distance = _distanceByTheater[theater.id];
                final showtimes = _showtimesForDate(theater, selectedDate);
                final selectedDateLabel = _showDateLabel(selectedDate);
                final selectedDateKey = _showDateKey(selectedDate);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theater.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        theater.address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (distance != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Cách bạn khoảng ${distance.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Ngày chiếu: $selectedDateLabel',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (showtimes.isEmpty)
                        const Text(
                          'Không còn suất chiếu khả dụng tại thời điểm hiện tại.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: showtimes
                              .map(
                                (time) => ActionChip(
                                  label: Text(time),
                                  onPressed: () async {
                                    final auth = Provider.of<AuthProvider>(context, listen: false);
                                    if (!auth.isAuthenticated) {
                                      await Navigator.pushNamed(
                                        context,
                                        AppRoutes.login,
                                      );
                                      if (!context.mounted) {
                                        return;
                                      }

                                      final signedInAuth = Provider.of<AuthProvider>(context, listen: false);
                                      if (!signedInAuth.isAuthenticated) {
                                        return;
                                      }
                                    }

                                    final showStartAt = _showtimeDateTime(
                                      selectedDate,
                                      time,
                                    );
                                    if (showStartAt == null ||
                                        !_isShowtimeBookable(showStartAt)) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Suất chiếu này vừa hết hạn đặt vé.',
                                          ),
                                        ),
                                      );
                                      setState(() => _now = DateTime.now());
                                      return;
                                    }

                                    if (!auth.canWatchAgeLabel(
                                      movie.ageLabel,
                                    )) {
                                      showDialog<void>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Không đủ độ tuổi'),
                                          content: Text(
                                            'Phim yêu cầu ${movie.ageLabel}. Vui lòng cập nhật ngày sinh hợp lệ.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Đóng'),
                                            ),
                                          ],
                                        ),
                                      );
                                      return;
                                    }

                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.seatSelection,
                                      arguments: {
                                        'movie': movie,
                                        'theaterId': theater.id,
                                        'theaterName': theater.name,
                                        'theaterAddress': theater.address,
                                        'showtimeId':
                                            '${theater.id}-$selectedDateKey-$time',
                                        'showtimeLabel':
                                            '$time - $selectedDateLabel',
                                        'showDateLabel': selectedDateLabel,
                                        'showDate': selectedDate
                                            .toIso8601String(),
                                        'showStartAt': showStartAt
                                            .toIso8601String(),
                                        'basePrice': 75000.0,
                                      },
                                    );
                                  },
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
