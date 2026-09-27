import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the customer's discovery location choice.  This prevents the
/// permission explainer from reappearing on every launch and lets Home and
/// Explore use the same strict location scope.
class SavedDiscoveryLocation {
  final bool decided;
  final String? city;
  final double? latitude;
  final double? longitude;

  const SavedDiscoveryLocation({
    required this.decided,
    this.city,
    this.latitude,
    this.longitude,
  });

  bool get nearMe => latitude != null && longitude != null;
}

class LocationPreferenceStore {
  static const _storage = FlutterSecureStorage();
  static const _kindKey = 'discovery_location_kind';
  static const _cityKey = 'discovery_location_city';
  static const _latitudeKey = 'discovery_location_latitude';
  static const _longitudeKey = 'discovery_location_longitude';

  Future<SavedDiscoveryLocation> read() async {
    final values = await _storage.readAll();
    final kind = values[_kindKey];
    if (kind == 'near') {
      final latitude = double.tryParse(values[_latitudeKey] ?? '');
      final longitude = double.tryParse(values[_longitudeKey] ?? '');
      if (latitude != null && longitude != null) {
        return SavedDiscoveryLocation(
          decided: true,
          latitude: latitude,
          longitude: longitude,
        );
      }
    }
    if (kind == 'city' && (values[_cityKey] ?? '').trim().isNotEmpty) {
      return SavedDiscoveryLocation(
        decided: true,
        city: values[_cityKey]!.trim(),
      );
    }
    return SavedDiscoveryLocation(decided: kind == 'dismissed');
  }

  Future<void> saveNearMe(double latitude, double longitude) async {
    await _storage.write(key: _kindKey, value: 'near');
    await _storage.write(key: _latitudeKey, value: '$latitude');
    await _storage.write(key: _longitudeKey, value: '$longitude');
    await _storage.delete(key: _cityKey);
  }

  Future<void> saveCity(String city) async {
    await _storage.write(key: _kindKey, value: 'city');
    await _storage.write(key: _cityKey, value: city.trim());
    await _storage.delete(key: _latitudeKey);
    await _storage.delete(key: _longitudeKey);
  }

  Future<void> saveDismissed() async {
    await _storage.write(key: _kindKey, value: 'dismissed');
    await _storage.delete(key: _cityKey);
    await _storage.delete(key: _latitudeKey);
    await _storage.delete(key: _longitudeKey);
  }
}
