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

const _listedCityCentres = <String, (double, double)>{
  'Bengaluru': (12.9716, 77.5946),
  'Bhubaneswar': (20.2961, 85.8245),
  'Chennai': (13.0827, 80.2707),
  'Hyderabad': (17.3850, 78.4867),
  'Pune': (18.5204, 73.8567),
};

/// Nearest city where bulk-imported listings are currently supported.
/// Used only as an honest fallback when listings do not yet have map pins.
String nearestListedCity(double latitude, double longitude) {
  return _listedCityCentres.entries.reduce((nearest, candidate) {
    final nearestDistance = distanceKm(
      latitude,
      longitude,
      nearest.value.$1,
      nearest.value.$2,
    );
    final candidateDistance = distanceKm(
      latitude,
      longitude,
      candidate.value.$1,
      candidate.value.$2,
    );
    return candidateDistance < nearestDistance ? candidate : nearest;
  }).key;
}
