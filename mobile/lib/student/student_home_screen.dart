import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../core/theme.dart';
import '../shared/app_states.dart';
import '../shared/brand/hi_pg_brand.dart';
import 'discovery/discovery_models.dart';
import 'discovery/discovery_repository.dart';
import 'discovery/city_picker_sheet.dart';
import 'discovery/location_lookup.dart';
import 'discovery/location_preference_store.dart';
import 'discovery/pg_poster_card.dart';

/// Student home tab: search first, then shortcuts to everything a student
/// comes back for (bookings, rent, support) and a rail of PGs to browse.
class StudentHomeScreen extends StatefulWidget {
  /// Injectable for tests; defaults to the public discovery API.
  final DiscoveryRepository? discovery;

  const StudentHomeScreen({super.key, this.discovery});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  static const double _nearbyRadiusKm = 15;

  late final DiscoveryRepository _discovery =
      widget.discovery ?? DiscoveryRepository();
  final _locationStore = LocationPreferenceStore();
  late Future<List<PgSearchResult>> _recommended;
  double? _latitude;
  double? _longitude;
  String? _selectedCity;
  bool _locating = false;
  bool _locationDecisionLoaded = false;
  String _locationLabel = 'Choose location';

  @override
  void initState() {
    super.initState();
    _recommended = _restoreLocationAndLoad();
  }

  Future<List<PgSearchResult>> _restoreLocationAndLoad() async {
    final saved = await _locationStore.read();
    _locationDecisionLoaded = saved.decided;
    _selectedCity = saved.city;
    _latitude = saved.latitude;
    _longitude = saved.longitude;
    if (saved.city != null) _locationLabel = saved.city!;
    if (saved.nearMe) _locationLabel = 'Near you';
    if (mounted) setState(() {});
    if (!saved.decided) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerLocation());
    }
    return _loadRecommended();
  }

  Future<List<PgSearchResult>> _loadRecommended() async {
    final page = await _discovery.search(city: _selectedCity);
    final results = page.content.toList();
    final latitude = _latitude;
    final longitude = _longitude;
    if (latitude != null && longitude != null) {
      results.removeWhere((pg) =>
          pg.latitude == null ||
          pg.longitude == null ||
          distanceKm(latitude, longitude, pg.latitude!, pg.longitude!) >
              _nearbyRadiusKm);
      results.sort((a, b) {
        final aDistance = a.latitude == null || a.longitude == null
            ? double.infinity
            : distanceKm(latitude, longitude, a.latitude!, a.longitude!);
        final bDistance = b.latitude == null || b.longitude == null
            ? double.infinity
            : distanceKm(latitude, longitude, b.latitude!, b.longitude!);
        return aDistance.compareTo(bDistance);
      });
    }
    return results.take(10).toList();
  }

  Future<void> _offerLocation() async {
    if (!mounted || _locationDecisionLoaded) return;
    _locationDecisionLoaded = true;
    final allow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Find stays near you'),
        content: const Text(
          'Allow location access to show available PGs closest to your current area.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Allow location'),
          ),
        ],
      ),
    );
    if (allow == true) {
      await _requestLocation();
    } else {
      await _locationStore.saveDismissed();
    }
  }

  Future<void> _chooseLocation() async {
    final current = _latitude != null && _longitude != null
        ? const LocationChoice.nearMe()
        : _selectedCity == null
            ? const LocationChoice.allCities()
            : LocationChoice.city(_selectedCity!);
    final picked = await showCityPicker(context, current: current);
    if (picked == null || !mounted) return;
    if (picked.nearMe) {
      await _requestLocation();
      return;
    }
    setState(() {
      _latitude = null;
      _longitude = null;
      _selectedCity = picked.city;
      _locationLabel = picked.city ?? 'All cities';
      _recommended = _loadRecommended();
    });
    if (picked.city == null) {
      await _locationStore.saveDismissed();
    } else {
      await _locationStore.saveCity(picked.city!);
    }
  }

  Future<void> _requestLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final lookup = await lookUpLocation();
    if (!mounted) return;
    if (!lookup.ok) {
      setState(() => _locating = false);
      final message = switch (lookup.problem) {
        LocationProblem.serviceOff =>
          'Turn on device location to see stays near you.',
        LocationProblem.deniedForever =>
          'Location is blocked. Enable it for hi pg in phone Settings.',
        LocationProblem.denied =>
          'Location permission was not allowed. You can choose it later.',
        _ => 'Your location could not be found. Please try again.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final position = lookup.position!;
    await _locationStore.saveNearMe(position.latitude, position.longitude);
    if (!mounted) return;
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _selectedCity = null;
      _locationLabel = 'Near you';
      _locating = false;
      _recommended = _loadRecommended();
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _recommended = _loadRecommended();
    });
    try {
      await _recommended;
    } catch (_) {
      // The rail hides itself when it cannot load.
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = context.watch<AuthState>().fullName?.trim() ?? '';
    final firstName =
        fullName.isEmpty ? null : fullName.split(RegExp(r'\s+')).first;
    return Scaffold(
      appBar: AppBar(
        title: const HiPgLockup(height: 26, wordColor: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Semantics(
              button: true,
              label: 'Account',
              child: Material(
                color: AppColors.brand,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.go('/student/account'),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Center(
                      child: fullName.isEmpty
                          ? const Icon(Icons.person_rounded,
                              color: Colors.white, size: 20)
                          : Text(
                              fullName.characters.first.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            _SearchBand(
              greeting: firstName == null ? 'Hello there' : 'Hi, $firstName',
              onSearch: () => context.go('/student/search'),
              locationLabel: _locationLabel,
              locating: _locating,
              onLocation: _chooseLocation,
            ),
            const SizedBox(height: 16),
            _PromoCarousel(onTap: () => context.go('/student/search')),
            const SizedBox(height: 24),
            _RecommendedRail(
              future: _recommended,
              onSeeAll: () => context.go('/student/search'),
              onOpen: (pg) => context.push('/student/pgs/${pg.id}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Charcoal band under the app bar: greeting and the search entry point.
class _SearchBand extends StatelessWidget {
  final String greeting;
  final VoidCallback onSearch;
  final String locationLabel;
  final bool locating;
  final VoidCallback onLocation;

  const _SearchBand({
    required this.greeting,
    required this.onSearch,
    required this.locationLabel,
    required this.locating,
    required this.onLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.ink,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                  ),
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(999),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: locating ? null : onLocation,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (locating)
                          const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(Icons.location_on_rounded,
                              size: 15, color: AppColors.brand),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 105),
                          child: Text(
                            locating ? 'Locating...' : locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Where are you staying next?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .72),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onSearch,
              child: const SizedBox(
                height: 46,
                child: Row(
                  children: [
                    SizedBox(width: 12),
                    Icon(Icons.search_rounded, color: AppColors.ink, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Search for PGs, areas and cities',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Promo {
  final String tag;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color accent;

  const _Promo({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.accent,
  });
}

const _promos = [
  _Promo(
    tag: 'LIVE AVAILABILITY',
    title: 'See which beds are\nfree before you visit',
    subtitle: 'Availability updates as beds are booked',
    icon: Icons.bed_rounded,
    background: AppColors.ink,
    foreground: Colors.white,
    accent: AppColors.brand,
  ),
  _Promo(
    tag: 'CLEAR PRICING',
    title: 'Compare monthly rent\nwithout the guesswork',
    subtitle: 'Rent per bed, shown upfront',
    icon: Icons.currency_rupee_rounded,
    background: AppColors.brandSoft,
    foreground: AppColors.ink,
    accent: AppColors.brandText,
  ),
  _Promo(
    tag: 'BOOK IN A FEW TAPS',
    title: 'Pick your room and\nbed, then pay securely',
    subtitle: 'Online or directly to the owner',
    icon: Icons.verified_user_outlined,
    background: AppColors.successSoft,
    foreground: AppColors.ink,
    accent: AppColors.success,
  ),
];

/// Auto-advancing banner strip. Holds still when the system asks for
/// reduced motion.
class _PromoCarousel extends StatefulWidget {
  final VoidCallback onTap;

  const _PromoCarousel({required this.onTap});

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _controller = PageController(viewportFraction: .92);
  Timer? _timer;
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (!MediaQuery.disableAnimationsOf(context)) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_controller.hasClients) return;
        _controller.animateToPage(
          (_index + 1) % _promos.length,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 148,
          child: PageView.builder(
            controller: _controller,
            itemCount: _promos.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final promo = _promos[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: promo.background,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  promo.tag,
                                  style: TextStyle(
                                    color: promo.background == AppColors.ink
                                        ? const Color(0xFFFF8FA3)
                                        : promo.accent,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  promo.title,
                                  maxLines: 2,
                                  style: TextStyle(
                                    color: promo.foreground,
                                    fontSize: 17.5,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  promo.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        promo.foreground.withValues(alpha: .75),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: promo.background == AppColors.ink
                                  ? AppColors.brand
                                  : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              promo.icon,
                              size: 28,
                              color: promo.background == AppColors.ink
                                  ? Colors.white
                                  : promo.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _promos.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == _index ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _index ? AppColors.brand : AppColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Horizontal rail of PG posters from the public search. Shows skeletons
/// while loading and disappears if nothing can be shown.
class _RecommendedRail extends StatelessWidget {
  final Future<List<PgSearchResult>> future;
  final VoidCallback onSeeAll;
  final ValueChanged<PgSearchResult> onOpen;

  const _RecommendedRail({
    required this.future,
    required this.onSeeAll,
    required this.onOpen,
  });

  static const _cardWidth = 140.0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PgSearchResult>>(
      future: future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final pgs = snapshot.data ?? const <PgSearchResult>[];
        if (!loading && pgs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
              child: SectionHeader(
                title: 'PGs to explore',
                actionLabel: 'See all ›',
                onAction: onSeeAll,
              ),
            ),
            SizedBox(
              height: _cardWidth * pgPosterImageHeightRatio +
                  MediaQuery.textScalerOf(context)
                      .scale(pgPosterTextHeight + 2),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: loading ? 4 : pgs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => loading
                    ? const PgPosterSkeleton(width: _cardWidth)
                    : PgPosterCard(
                        width: _cardWidth,
                        pg: pgs[index],
                        onTap: () => onOpen(pgs[index]),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
