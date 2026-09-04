import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'auth/auth_state.dart';
import 'core/theme.dart';

void main() {
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
        title: 'PG Platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: _router,
      ),
    );
  }
}
