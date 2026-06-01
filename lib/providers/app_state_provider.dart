import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/utils/network_info.dart';

class AppStateProvider extends ChangeNotifier {
  AppStateProvider({required NetworkInfo networkInfo})
    : _networkInfo = networkInfo;

  final NetworkInfo _networkInfo;
  StreamSubscription<bool>? _networkSubscription;

  bool _isOnline = true;
  bool _isBootstrapped = false;
  String? _warning;

  bool get isOnline => _isOnline;
  bool get isBootstrapped => _isBootstrapped;
  String? get warning => _warning;

  void setOnline(bool value) {
    _isOnline = value;
    notifyListeners();
  }

  Future<void> bootstrap({
    required bool firebaseReady,
    required bool localStorageReady,
  }) async {
    _isOnline = await _networkInfo.isConnected();

    if (!firebaseReady) {
      _warning = 'Firebase is not configured yet. Running in demo mode.';
    } else if (!localStorageReady) {
      _warning = 'Local cache is not available. Offline mode is limited.';
    } else {
      _warning = null;
    }

    _networkSubscription ??= _networkInfo.watchConnection().listen((
      isConnected,
    ) {
      _isOnline = isConnected;
      notifyListeners();
    });

    _isBootstrapped = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    super.dispose();
  }
}
