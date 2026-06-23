import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  LocaleProvider({Locale? initial}) : _locale = initial ?? const Locale('vi');

  Locale _locale;

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (locale == _locale) return;
    _locale = locale;
    notifyListeners();
  }
}
