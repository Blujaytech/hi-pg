/// Build-time environment config, read via --dart-define.
///
/// Release-ready builds use the production Cloud Run API by default. Local
/// Android development is still available explicitly with the emulator host
/// alias.
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
    defaultValue:
        'https://hi-pg-api-production-861205582126.asia-south1.run.app/api/v1',
  );

  // OAuth client IDs are public identifiers, not secrets. Every build must
  // explicitly select the Firebase/Google project it belongs to so a staging
  // or production APK can never silently authenticate against a retired
  // project.
  static const String googleOAuthWebClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static const String _legalBaseUrlOverride = String.fromEnvironment(
    'LEGAL_BASE_URL',
    defaultValue: 'https://hipg-website.pages.dev',
  );

  /// Public Privacy Policy, Terms and account-deletion pages. Production uses
  /// the Cloudflare Pages legal site by default; another environment can
  /// override the origin without changing application code.
  static String get legalBaseUrl {
    if (_legalBaseUrlOverride.isNotEmpty) {
      return _legalBaseUrlOverride.replaceAll(RegExp(r'/$'), '');
    }
    final api = Uri.parse(apiBaseUrl);
    return api
        .replace(path: '', query: null, fragment: null)
        .toString()
        .replaceAll(RegExp(r'/$'), '');
  }

  static bool get usesLocalBackend =>
      apiBaseUrl.contains('10.0.2.2') ||
      apiBaseUrl.contains('127.0.0.1') ||
      apiBaseUrl.contains('localhost');
}
