/// Build-time environment config, read via --dart-define. Example:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
///
/// 10.0.2.2 is the Android emulator's alias for the host machine's localhost;
/// use localhost on iOS simulator / a LAN IP on a physical device.
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1',
  );
}
