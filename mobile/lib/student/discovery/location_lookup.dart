import 'package:geolocator/geolocator.dart';

/// Why the device's location could not be read.
enum LocationProblem { serviceOff, denied, deniedForever, unavailable }

/// Either a position or the reason there isn't one.
class LocationLookup {
  final Position? position;
  final LocationProblem? problem;

  const LocationLookup._(this.position, this.problem);

  bool get ok => position != null;
}

/// Reads the device's current position for "PGs near me", asking for
/// permission the first time. City-level accuracy is plenty, so it asks for
/// a low-accuracy fix and falls back to the last known one if a fresh fix is
/// slow.
Future<LocationLookup> lookUpLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationLookup._(null, LocationProblem.serviceOff);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationLookup._(null, LocationProblem.deniedForever);
    }
    if (permission == LocationPermission.denied) {
      return const LocationLookup._(null, LocationProblem.denied);
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationLookup._(position, null);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      return last == null
          ? const LocationLookup._(null, LocationProblem.unavailable)
          : LocationLookup._(last, null);
    }
  } catch (_) {
    return const LocationLookup._(null, LocationProblem.unavailable);
  }
}

/// Straight-line distance in kilometres.
double distanceKm(double fromLat, double fromLng, double toLat, double toLng) =>
    Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng) / 1000;
