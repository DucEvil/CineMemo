import 'package:flutter/foundation.dart';

class ProfileProvider extends ChangeNotifier {
  String _displayName = '';

  String get displayName => _displayName;

  void setDisplayName(String value) {
    _displayName = value;
    notifyListeners();
  }
}
