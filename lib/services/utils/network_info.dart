import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkInfo {
  NetworkInfo({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return _hasNetwork(result);
  }

  Stream<bool> watchConnection() {
    return _connectivity.onConnectivityChanged.map(_hasNetwork);
  }

  bool _hasNetwork(dynamic connectivityResult) {
    if (connectivityResult is List<ConnectivityResult>) {
      return connectivityResult.any(
        (result) => result != ConnectivityResult.none,
      );
    }
    if (connectivityResult is ConnectivityResult) {
      return connectivityResult != ConnectivityResult.none;
    }
    return false;
  }
}
