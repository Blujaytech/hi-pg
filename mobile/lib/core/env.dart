/// Build-time environment config, read via --dart-define.
///
/// Release-ready builds use the deployed Render API by default. Local Android
/// development is still available explicitly with the emulator host alias.
///
/// Override this at build time only when targeting another environment:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
///
/// 10.0.2.2 is the Android emulator's alias for the host machine's localhost;
/// use localhost on iOS simulator / a LAN IP on a physical device.
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pg-platform-api.onrender.com/api/v1',
  );

  // OAuth client IDs are public identifiers, not secrets. Every build must
  // explicitly select the Firebase/Google project it belongs to so a staging
  // or production APK can never silently authenticate against a retired
  // project.
  static const String googleOAuthWebClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static bool get usesLocalBackend =>
      apiBaseUrl.contains('10.0.2.2') ||
      apiBaseUrl.contains('127.0.0.1') ||
      apiBaseUrl.contains('localhost');
}
