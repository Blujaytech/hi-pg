import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pg_platform_mobile/auth/auth_state.dart';
import 'package:pg_platform_mobile/student/discovery/discovery_models.dart';
import 'package:pg_platform_mobile/student/discovery/discovery_repository.dart';
import 'package:pg_platform_mobile/student/discovery/pg_search_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('keeps the Explore landing page focused and compact',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/student/explore',
      routes: [
        GoRoute(
          path: '/student/explore',
          builder: (_, __) => PgSearchScreen(repository: _EmptyDiscovery()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthState>.value(
        value: AuthState(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('How long are you staying?'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Day-wise'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Men'), findsOneWidget);
    expect(find.text('Women'), findsOneWidget);
    expect(find.text('Co-Living'), findsOneWidget);

    expect(find.text('PGs & hostels near me'), findsNothing);
    expect(find.text('Popular cities'), findsNothing);
    expect(find.text('Popular areas'), findsNothing);
    expect(find.textContaining('Browse all'), findsNothing);
    expect(find.text('Sort'), findsNothing);
    expect(find.text('Available now'), findsNothing);
    expect(find.text('Under ₹8k'), findsNothing);
  });
}

class _EmptyDiscovery extends DiscoveryRepository {
  @override
  Future<PagedResult<PgSearchResult>> search({
    String? query,
    String? city,
    GenderPreference? genderPreference,
    double? minRent,
    double? maxRent,
    int page = 0,
  }) async =>
      PagedResult(
        content: const [],
        page: 0,
        totalPages: 0,
        totalElements: 0,
      );
}
