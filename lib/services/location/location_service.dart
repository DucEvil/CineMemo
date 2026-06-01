import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<bool> isServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  Future<bool> ensurePermission() async {
    final serviceEnabled = await isServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Position?> getCurrentPosition() async {
    final granted = await ensurePermission();
    if (!granted) {
      return null;
    }

    try {
      final settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              forceLocationManager: true,
              timeLimit: Duration(seconds: 12),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 12),
            );

      return await Geolocator.getCurrentPosition(locationSettings: settings);
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  Future<Position?> getLastKnownPosition() {
    return Geolocator.getLastKnownPosition();
  }

  double distanceInKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    final distanceInMeters = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
    return distanceInMeters / 1000;
  }
}
