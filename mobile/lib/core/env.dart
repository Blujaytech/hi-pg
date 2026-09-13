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

  // OAuth client IDs are public identifiers, not secrets. Override this for a
  // different Google Cloud project with --dart-define at build time.
  static const String googleOAuthWebClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_WEB_CLIENT_ID',
    defaultValue:
        '83954662324-8tsednfctojp1stj3o7rc7fvs02m1lds.apps.googleusercontent.com',
  );

  static bool get usesLocalBackend =>
      apiBaseUrl.contains('10.0.2.2') ||
      apiBaseUrl.contains('127.0.0.1') ||
      apiBaseUrl.contains('localhost');
}
