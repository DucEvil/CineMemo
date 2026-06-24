import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'No AppLocalizations found in context');
    return localizations!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'vi': {
      'appName': 'CineMemo',
      'appSubtitle': 'Đặt vé nhanh, lưu kỷ niệm điện ảnh của bạn',
      'voucherOffers': 'Voucher ưu đãi',
      'seeAll': 'Xem tất cả',
      'login': 'Đăng nhập',
      'register': 'Đăng ký',
      'supportTitle': 'CineMemo hỗ trợ',
      'nowShowing': 'Đang chiếu',
      'comingSoon': 'Sắp chiếu',
      'languageVi': 'Vi',
      'languageEn': 'En',
    },
    'en': {
      'appName': 'CineMemo',
      'appSubtitle': 'Fast ticket booking, save your cinema memories',
      'voucherOffers': 'Voucher offers',
      'seeAll': 'See all',
      'login': 'Login',
      'register': 'Register',
      'supportTitle': 'CineMemo support',
      'nowShowing': 'Now showing',
      'comingSoon': 'Coming soon',
      'languageVi': 'Vi',
      'languageEn': 'En',
    },
  };

  String translate(String key) {
    final languageCode = locale.languageCode;
    final values = _localizedValues[languageCode] ?? _localizedValues['vi']!;
    return values[key] ?? _localizedValues['vi']![key] ?? key;
  }

  String get appName => translate('appName');
  String get appSubtitle => translate('appSubtitle');
  String get voucherOffers => translate('voucherOffers');
  String get seeAll => translate('seeAll');
  String get login => translate('login');
  String get register => translate('register');
  String get supportTitle => translate('supportTitle');
  String get nowShowing => translate('nowShowing');
  String get comingSoon => translate('comingSoon');
  String get languageVi => translate('languageVi');
  String get languageEn => translate('languageEn');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['vi', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
