import 'package:flutter/material.dart';

import '../models/movie_model.dart';
import '../screens/auth/birthdate_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/booking/booking_success_screen.dart';
import '../screens/booking/momo_qr_payment_screen.dart';
import '../screens/booking/payment_screen.dart';
import '../screens/booking/seat_selection_screen.dart';
import '../screens/booking/showtime_selection_screen.dart';
import '../screens/movie/movie_list_screen.dart';
import '../screens/movie/movie_detail_screen.dart';
import '../screens/movie/movie_search_screen.dart';
import '../screens/movie/voucher_list_screen.dart';
import '../screens/profile/booking_history_screen.dart';
import '../screens/profile/favorites_screen.dart';
import '../screens/profile/personal_statistics_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/review/create_review_screen.dart';
import '../screens/review/my_review_screen.dart';
import '../screens/review/review_list_screen.dart';
import 'app_routes.dart';

class RouteGenerator {
  static Route<dynamic> generate(RouteSettings settings) {
    final routeName = settings.name ?? '';
    if (_isMomoCallbackRoute(routeName)) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const _IgnoreMomoCallbackRouteScreen(),
      );
    }

    switch (settings.name) {
      case AppRoutes.movieList:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MovieListScreen(),
        );
      case AppRoutes.movieSearch:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MovieSearchScreen(),
        );
      case AppRoutes.voucherList:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const VoucherListScreen(),
        );
      case AppRoutes.login:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );
      case AppRoutes.birthdate:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const BirthdateScreen(),
        );
      case AppRoutes.movieDetail:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              MovieDetailScreen(movie: settings.arguments as MovieModel?),
        );
      case AppRoutes.showtimeSelection:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ShowtimeSelectionScreen(
            movie: _extractMovieArgument(settings.arguments),
          ),
        );
      case AppRoutes.seatSelection:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SeatSelectionScreen(),
        );
      case AppRoutes.payment:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PaymentScreen(),
        );
      case AppRoutes.momoQrPayment:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MomoQrPaymentScreen(),
        );
      case AppRoutes.bookingSuccess:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const BookingSuccessScreen(),
        );
      case AppRoutes.booking:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const BookingHistoryScreen(),
        );
      case AppRoutes.favorites:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const FavoritesScreen(),
        );
      case AppRoutes.reviewList:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ReviewListScreen(),
        );
      case AppRoutes.myReviews:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MyReviewScreen(),
        );
      case AppRoutes.createReview:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CreateReviewScreen(),
        );
      case AppRoutes.profile:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ProfileScreen(),
        );
      case AppRoutes.personalStatistics:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PersonalStatisticsScreen(),
        );
      // Gemini translation screen was removed; fallthrough to default.
      case AppRoutes.adminDashboard:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AdminDashboardScreen(),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Route not found')),
            body: Center(child: Text('No route for ${settings.name}')),
          ),
        );
    }
  }

  static MovieModel? _extractMovieArgument(Object? arguments) {
    if (arguments is MovieModel) {
      return arguments;
    }

    if (arguments is Map) {
      final candidate = arguments['movie'];
      if (candidate is MovieModel) {
        return candidate;
      }
    }

    return null;
  }

  static bool _isMomoCallbackRoute(String routeName) {
    final normalized = routeName.trim().toLowerCase();
    final looksLikeCallbackPath =
        normalized.startsWith('/?') ||
        normalized.startsWith('/payment-callback');
    if (!looksLikeCallbackPath) {
      return false;
    }

    final uri = Uri.tryParse(routeName);
    if (uri == null) {
      return false;
    }

    final orderId = (uri.queryParameters['orderId'] ?? '').trim();
    if (orderId.isEmpty) {
      return false;
    }

    return uri.queryParameters.containsKey('partnerCode') ||
        uri.queryParameters.containsKey('resultCode') ||
        uri.queryParameters.containsKey('orderType');
  }
}

class _IgnoreMomoCallbackRouteScreen extends StatefulWidget {
  const _IgnoreMomoCallbackRouteScreen();

  @override
  State<_IgnoreMomoCallbackRouteScreen> createState() =>
      _IgnoreMomoCallbackRouteScreenState();
}

class _IgnoreMomoCallbackRouteScreenState
    extends State<_IgnoreMomoCallbackRouteScreen> {
  bool _handled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handled) {
      return;
    }
    _handled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }

      navigator.pushReplacementNamed(AppRoutes.movieList);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
