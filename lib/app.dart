import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'bootstrap/app_bootstrap.dart';
import 'localization/app_localizations.dart';
import 'providers/app_state_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/movie_provider.dart';
import 'providers/review_provider.dart';
import 'screens/auth/birthdate_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/movie/movie_list_screen.dart';
import 'services/api/vietnam_movie_api.dart';
import 'services/firebase/firebase_analytics_service.dart';
import 'services/firebase/firebase_auth_service.dart';
import 'services/firebase/firebase_firestore_service.dart';
import 'services/integrations/google_calendar_service.dart';
import 'services/integrations/ticket_email_service.dart';
import 'services/location/location_service.dart';
import 'services/notifications/showtime_reminder_service.dart';
import 'services/payment/momo_payment_service.dart';
import 'services/firebase/firebase_storage_service.dart';
import 'services/storage/local_storage_service.dart';
import 'services/translation/translation_service.dart';
import 'services/utils/network_info.dart';
import 'services/weather/weather_service.dart';
import 'utils/app_colors.dart';
import 'utils/app_routes.dart';
import 'utils/route_generator.dart';

class CineMemoRootApp extends StatelessWidget {
  const CineMemoRootApp({super.key, required this.bootstrap});

  final AppBootstrapResult bootstrap;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => FirebaseAuthService()),
        Provider(create: (_) => FirebaseFirestoreService()),
        Provider(
          create: (context) => GoogleCalendarService(
            authService: Provider.of<FirebaseAuthService>(
              context,
              listen: false,
            ),
          ),
        ),
        Provider(create: (_) => TicketEmailService()),
        Provider(create: (_) => TranslationService()),
        Provider(
          create: (context) => ShowtimeReminderService(
            firestoreService: Provider.of<FirebaseFirestoreService>(
              context,
              listen: false,
            ),
          ),
        ),
        Provider(create: (_) => VietnamMovieApi()),
        Provider(create: (_) => LocationService()),
        Provider(create: (_) => WeatherService()),
        Provider(create: (_) => FirebaseStorageService()),
        Provider(create: (_) => MomoPaymentService()),
        Provider(
          create: (_) {
            final storage = LocalStorageService();
            storage.init();
            return storage;
          },
        ),
        Provider(create: (_) => NetworkInfo()),
        ChangeNotifierProvider(
          create: (context) {
            final provider = AppStateProvider(
              networkInfo: Provider.of<NetworkInfo>(context, listen: false),
            );
            provider.bootstrap(
              firebaseReady: bootstrap.firebaseReady,
              localStorageReady: bootstrap.localStorageReady,
            );
            return provider;
          },
        ),
        Provider(create: (_) => FirebaseAnalyticsService()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(
          create: (context) {
            final authProvider = AuthProvider(
              authService: Provider.of<FirebaseAuthService>(
                context,
                listen: false,
              ),
              firestoreService: Provider.of<FirebaseFirestoreService>(
                context,
                listen: false,
              ),
              analyticsService: Provider.of<FirebaseAnalyticsService>(
                context,
                listen: false,
              ),
              firebaseEnabled: bootstrap.firebaseReady,
            );
            authProvider.initialize();
            return authProvider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, MovieProvider>(
          create: (context) {
            final movieProvider = MovieProvider(
              movieApi: Provider.of<VietnamMovieApi>(context, listen: false),
              localStorageService: Provider.of<LocalStorageService>(
                context,
                listen: false,
              ),
              firestoreService: Provider.of<FirebaseFirestoreService>(
                context,
                listen: false,
              ),
            );
            movieProvider.syncFavoriteScope(
              Provider.of<AuthProvider>(context, listen: false).uid,
            );
            movieProvider.loadFavoriteMovieIds();
            movieProvider.loadHomeData();
            return movieProvider;
          },
          update: (context, auth, movieProvider) {
            final provider =
                movieProvider ??
                MovieProvider(
                  movieApi: Provider.of<VietnamMovieApi>(
                    context,
                    listen: false,
                  ),
                  localStorageService: Provider.of<LocalStorageService>(
                    context,
                    listen: false,
                  ),
                  firestoreService: Provider.of<FirebaseFirestoreService>(
                    context,
                    listen: false,
                  ),
                );
            provider.syncFavoriteScope(auth.uid);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ReviewProvider>(
          create: (context) => ReviewProvider(
            firestoreService: Provider.of<FirebaseFirestoreService>(
              context,
              listen: false,
            ),
          ),
          update: (context, auth, provider) {
            final reviewProvider =
                provider ??
                ReviewProvider(
                  firestoreService: Provider.of<FirebaseFirestoreService>(
                    context,
                    listen: false,
                  ),
                );
            reviewProvider.bindUser(auth.uid);
            return reviewProvider;
          },
        ),
        Provider(create: (_) => FirebaseAnalyticsService()),
        ChangeNotifierProvider(
          create: (context) => BookingProvider(
            firestoreService: Provider.of<FirebaseFirestoreService>(
              context,
              listen: false,
            ),
            momoPaymentService: Provider.of<MomoPaymentService>(
              context,
              listen: false,
            ),
            googleCalendarService: Provider.of<GoogleCalendarService>(
              context,
              listen: false,
            ),
            ticketEmailService: Provider.of<TicketEmailService>(
              context,
              listen: false,
            ),
            showtimeReminderService: Provider.of<ShowtimeReminderService>(
              context,
              listen: false,
            ),
            analyticsService: Provider.of<FirebaseAnalyticsService>(
              context,
              listen: false,
            ),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final analyticsService = Provider.of<FirebaseAnalyticsService>(
            context,
            listen: false,
          );
          final localeProvider = Provider.of<LocaleProvider>(context);

          return MaterialApp(
            locale: localeProvider.locale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              AppLocalizations.delegate,
            ],
            supportedLocales: const [Locale('vi'), Locale('en')],
            debugShowCheckedModeBanner: false,
            title: 'CineMemo',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                secondary: AppColors.accent,
                onSecondary: AppColors.textPrimary,
                tertiary: AppColors.highlight,
                onTertiary: Colors.white,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
                error: AppColors.danger,
                onError: Colors.white,
              ),
              scaffoldBackgroundColor: AppColors.scaffold,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                centerTitle: false,
                surfaceTintColor: Colors.transparent,
              ),
              textTheme: ThemeData.light().textTheme
                  .copyWith(
                    titleLarge: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                    titleMedium: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    bodyLarge: const TextStyle(fontSize: 15, height: 1.45),
                    bodyMedium: const TextStyle(fontSize: 14, height: 1.42),
                    labelLarge: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                  .apply(
                    bodyColor: AppColors.textPrimary,
                    displayColor: AppColors.textPrimary,
                  ),
              chipTheme: ChipThemeData(
                backgroundColor: AppColors.surfaceAlt,
                selectedColor: AppColors.primary.withValues(alpha: 0.12),
                side: const BorderSide(color: AppColors.border),
                labelStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: Colors.white,
                indicatorColor: AppColors.primary.withValues(alpha: 0.14),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  return TextStyle(
                    color: states.contains(WidgetState.selected)
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w700
                        : FontWeight.w500,
                  );
                }),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.4,
                  ),
                ),
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                shadowColor: Colors.black.withValues(alpha: 0.12),
              ),
            ),
            navigatorObservers: [analyticsService.observer],
            onGenerateRoute: RouteGenerator.generate,
            home: const _AppEntry(),
            routes: {
              AppRoutes.login: (_) => const LoginScreen(),
              AppRoutes.birthdate: (_) => const BirthdateScreen(),
            },
          );
        },
      ),
    );
  }
}

class _AppEntry extends StatelessWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        if (!appState.isBootstrapped) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const MovieListScreen();
      },
    );
  }
}
