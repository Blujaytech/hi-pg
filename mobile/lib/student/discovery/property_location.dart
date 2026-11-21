import 'package:flutter/services.dart';

class PropertyCoordinates {
  final double latitude;
  final double longitude;

  const PropertyCoordinates(this.latitude, this.longitude);
}

String propertyDestination({
  String? locationUrl,
  required String name,
  required String address,
  required String city,
  String? state,
  String? pincode,
}) {
  if (locationUrl != null) {
    final uri = Uri.tryParse(locationUrl);
    final query = uri?.queryParameters['query']?.trim();
    if (query != null && query.isNotEmpty) return query;
  }
  return [name, address, city, state, pincode]
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(', ');
}

Uri propertyMapUri(String? locationUrl, String destination) {
  final exact = locationUrl == null ? null : Uri.tryParse(locationUrl);
  if (exact != null && exact.scheme == 'https') return exact;
  return Uri.https(
    'www.google.com',
    '/maps/search/',
    {'api': '1', 'query': destination},
  );
}

Uri propertyDirectionsUri(String destination) => Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'destination': destination,
        'travelmode': 'driving',
        'dir_action': 'navigate',
      },
    );

const _geocodingChannel = MethodChannel('hipg/property-geocoding');

Future<PropertyCoordinates?> geocodeProperty(String destination) async {
  try {
    final result = await _geocodingChannel.invokeMapMethod<String, dynamic>(
      'resolve',
      {'query': destination},
    );
    final latitude = (result?['latitude'] as num?)?.toDouble();
    final longitude = (result?['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    return PropertyCoordinates(latitude, longitude);
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}
