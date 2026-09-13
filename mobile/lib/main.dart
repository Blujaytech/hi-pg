import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'auth/auth_state.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Inter'], license);
  });
  // Draw behind the status and navigation bars on every Android version
  // (Android 15+ enforces this anyway); screens pad with SafeArea.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.lightChrome);
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  runApp(const PgPlatformApp());
}

class PgPlatformApp extends StatefulWidget {
  const PgPlatformApp({super.key});

  @override
  State<PgPlatformApp> createState() => _PgPlatformAppState();
}

class _PgPlatformAppState extends State<PgPlatformApp> {
  final AuthState _authState = AuthState();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(_authState);
    _authState.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthState>.value(
      value: _authState,
      child: MaterialApp.router(
        title: 'hi pg',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // The branded surfaces are a deliberately light monochrome system.
        // Keep it consistent on devices set to dark mode until a complete,
        // contrast-audited dark palette is designed.
        themeMode: ThemeMode.light,
        routerConfig: _router,
        // Respect large-text accessibility settings, but cap them where the
        // fixed-height cards and tab bar would start to clip.
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: child!,
        ),
      ),
    );
  }
}
