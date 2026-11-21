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
import 'profile/customer_profile_repository.dart';

/// Student home tab: search first, then shortcuts to everything a student
/// comes back for (bookings, rent, support) and a rail of PGs to browse.
class StudentHomeScreen extends StatefulWidget {
  /// Injectable for tests; defaults to the public discovery API.
  final DiscoveryRepository? discovery;
  final CustomerProfileRepository? profileRepository;

  const StudentHomeScreen({
    super.key,
    this.discovery,
    this.profileRepository,
  });

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with SingleTickerProviderStateMixin {
  static const double _nearbyRadiusKm = 15;

  late final DiscoveryRepository _discovery =
      widget.discovery ?? DiscoveryRepository();
  late final CustomerProfileRepository _profileRepository =
      widget.profileRepository ?? CustomerProfileRepository();
  final _locationStore = LocationPreferenceStore();
  late Future<_HomeRecommendations> _recommended;
  double? _latitude;
  double? _longitude;
  String? _selectedCity;
  bool _locating = false;
  bool _locationDecisionLoaded = false;
  String _locationLabel = 'Choose location';
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    _recommended = _restoreLocationAndLoad();
    _loadProfilePhoto();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final profile = await _profileRepository.getMine();
      if (!mounted) return;
      context.read<AuthState>().updateStudentProfile(
            name: profile.fullName,
            photoUrl: profile.profilePhotoUrl,
          );
    } catch (_) {
      // Recommendations and navigation remain usable if profile loading fails.
    }
  }

  Future<_HomeRecommendations> _restoreLocationAndLoad() async {
    final saved = await _locationStore.read();
    _locationDecisionLoaded = saved.decided;
    _selectedCity = saved.city;
    _latitude = saved.latitude;
    _longitude = saved.longitude;
    if (saved.nearMe) {
      _selectedCity = nearestListedCity(saved.latitude!, saved.longitude!);
    }
    if (saved.city != null) _locationLabel = saved.city!;
    if (saved.nearMe) _locationLabel = 'Near you';
    if (mounted) setState(() {});
    if (!saved.decided) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerLocation());
    }
    return _loadRecommended();
  }

  Future<_HomeRecommendations> _loadRecommended() async {
    final page = await _discovery.search(city: _selectedCity);
    final results = page.content.take(30).toList();
    final latitude = _latitude;
    final longitude = _longitude;
    var nearby = const <PgSearchResult>[];
    if (latitude != null && longitude != null) {
      nearby = results
          .where((pg) =>
              pg.latitude != null &&
              pg.longitude != null &&
              distanceKm(latitude, longitude, pg.latitude!, pg.longitude!) <=
                  _nearbyRadiusKm)
          .toList();
      nearby.sort((a, b) {
        final aDistance =
            distanceKm(latitude, longitude, a.latitude!, a.longitude!);
        final bDistance =
            distanceKm(latitude, longitude, b.latitude!, b.longitude!);
        return aDistance.compareTo(bDistance);
      });
    }
    return _HomeRecommendations(
      pgs: results,
      nearby: nearby.take(10).toList(),
      city: _selectedCity,
      cityFallback: latitude != null &&
          longitude != null &&
          nearby.isEmpty &&
          results.any((pg) => pg.latitude == null || pg.longitude == null),
    );
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
      _selectedCity = nearestListedCity(position.latitude, position.longitude);
      _locationLabel = 'Near you';
      _locating = false;
      _recommended = _loadRecommended();
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _recommended = _loadRecommended();
    });
    await _loadProfilePhoto();
    try {
      await _recommended;
    } catch (_) {
      // The rail hides itself when it cannot load.
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = context.watch<AuthState>().fullName?.trim() ?? '';
    final profilePhotoUrl = context.watch<AuthState>().profilePhotoUrl;
    final firstName =
        fullName.isEmpty ? null : fullName.split(RegExp(r'\s+')).first;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      drawer: const _CustomerDrawer(),
      body: Builder(
        builder: (scaffoldContext) => RefreshIndicator(
          color: AppColors.brand,
          onRefresh: _refresh,
          child: ListView(
            key: const Key('student-home-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _HomeReveal(
                animation: _entrance,
                interval: const Interval(0, .48, curve: Curves.easeOutCubic),
                distance: 22,
                child: _PremiumHero(
                  greeting:
                      firstName == null ? 'Hello there' : 'Hi, $firstName',
                  fullName: fullName,
                  profilePhotoUrl: profilePhotoUrl,
                  locationLabel: _locationLabel,
                  locating: _locating,
                  onMenu: () => Scaffold.of(scaffoldContext).openDrawer(),
                  onNotifications: () => context.push('/notifications'),
                  onAccount: () => context.go('/student/account'),
                  onLocation: _chooseLocation,
                  onSearch: () => context.go('/student/search'),
                ),
              ),
              const SizedBox(height: 22),
              _HomeReveal(
                animation: _entrance,
                interval: const Interval(.12, .58, curve: Curves.easeOutCubic),
                child: _PromoCarousel(
                  onTap: () => context.go('/student/search'),
                ),
              ),
              const SizedBox(height: 30),
              _HomeReveal(
                animation: _entrance,
                interval: const Interval(.22, .68, curve: Curves.easeOutCubic),
                child: _CategoryStrip(
                  onCategory: (category) => context.go(
                    '/student/search?category=${category.queryValue}',
                  ),
                ),
              ),
              const SizedBox(height: 34),
              _HomeReveal(
                animation: _entrance,
                interval: const Interval(.32, .84, curve: Curves.easeOutCubic),
                child: _DiscoverySections(
                  future: _recommended,
                  onSeeAll: () => context.go('/student/search?browse=all'),
                  onCategory: (category) => context.go(
                    '/student/search?category=${category.queryValue}',
                  ),
                  onOpen: (pg) => context.push('/student/pgs/${pg.id}'),
                  onRetry: () => setState(() {
                    _recommended = _loadRecommended();
                  }),
                ),
              ),
              const SizedBox(height: 36),
              _HomeReveal(
                animation: _entrance,
                interval: const Interval(.46, .94, curve: Curves.easeOutCubic),
                child: const _TrustStrip(),
              ),
              const SizedBox(height: 28),
              _HomeReveal(
                animation: _entrance,
                interval: const Interval(.56, 1, curve: Curves.easeOutCubic),
                child: _DiscoveryCta(
                  onSearch: () => context.go('/student/search'),
                  onBrowse: () => context.go('/student/search?browse=all'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerDrawer extends StatelessWidget {
  const _CustomerDrawer();

  void _go(BuildContext context, String route) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final drawerWidth =
        (MediaQuery.sizeOf(context).width * .88).clamp(0, 356).toDouble();
    return Drawer(
      width: drawerWidth,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFFAFB),
                    Color(0xFFFFE8ED),
                    Color(0xFFFFF4F6),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -38,
                    top: -44,
                    child: Container(
                      width: 126,
                      height: 126,
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: .08),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const HiPgPlainLogo(fontSize: 38),
                      const SizedBox(height: 16),
                      Text(
                        'Everything for your stay',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Find Your PG. Feel at Home.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.muted,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                children: [
                  _DrawerDestination(
                    index: 0,
                    active: true,
                    icon: Icons.home_rounded,
                    label: 'Home',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _DrawerDestination(
                    index: 1,
                    icon: Icons.search_rounded,
                    label: 'Find a PG',
                    onTap: () => _go(context, '/student/search'),
                  ),
                  _DrawerDestination(
                    index: 2,
                    icon: Icons.event_available_rounded,
                    label: 'My bookings',
                    onTap: () => _go(context, '/student/bookings'),
                  ),
                  _DrawerDestination(
                    index: 3,
                    icon: Icons.receipt_long_rounded,
                    label: 'Fees and payments',
                    onTap: () => _go(context, '/student/fees'),
                  ),
                  _DrawerDestination(
                    index: 4,
                    icon: Icons.forum_rounded,
                    label: 'Complaints',
                    onTap: () => _go(context, '/student/complaints'),
                  ),
                  _DrawerDestination(
                    index: 5,
                    icon: Icons.support_agent_rounded,
                    label: 'Help and support',
                    onTap: () => _go(context, '/support'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: _DrawerDestination(
                index: 6,
                icon: Icons.person_rounded,
                label: 'Profile',
                prominent: true,
                onTap: () => _go(context, '/student/profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerDestination extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool active;
  final bool prominent;
  final VoidCallback onTap;

  const _DrawerDestination({
    required this.index,
    required this.icon,
    required this.label,
    this.active = false,
    this.prominent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : Duration(milliseconds: 300 + (index * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset((1 - value) * -14, 0),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Material(
          color: active
              ? AppColors.brandSoft
              : (prominent ? const Color(0xFFFFF7F9) : Colors.transparent),
          borderRadius: BorderRadius.circular(17),
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: active || prominent
                          ? AppColors.brand
                          : AppColors.fill,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: active || prominent ? Colors.white : AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w600,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: active ? AppColors.brand : AppColors.subtle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _HomeCategory {
  men(
    'Men\'s PG',
    'Comfort-first rooms',
    'men',
    Icons.male_rounded,
    'assets/home/mens_pg.jpg',
  ),
  women(
    'Women\'s PG',
    'Safe, bright spaces',
    'women',
    Icons.female_rounded,
    'assets/home/womens_pg.jpg',
  ),
  coliving(
    'Co-living',
    'Community living',
    'coliving',
    Icons.groups_rounded,
    'assets/home/coliving.jpg',
  ),
  monthly(
    'Monthly',
    'Flexible long stays',
    'monthly',
    Icons.calendar_month_rounded,
    null,
  ),
  dayWise(
    'Day-wise',
    'Book only the days',
    'day-wise',
    Icons.schedule_rounded,
    null,
  );

  final String label;
  final String subtitle;
  final String queryValue;
  final IconData icon;
  final String? imageAsset;

  const _HomeCategory(
    this.label,
    this.subtitle,
    this.queryValue,
    this.icon,
    this.imageAsset,
  );
}

class _CategoryStrip extends StatelessWidget {
  final ValueChanged<_HomeCategory> onCategory;

  const _CategoryStrip({required this.onCategory});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find your kind of stay',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.45,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Explore spaces shaped around your routine',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: _HomeCategory.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final category = _HomeCategory.values[index];
              return _StayCategoryCard(
                category: category,
                alternate: index.isOdd,
                onTap: () => onCategory(category),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StayCategoryCard extends StatelessWidget {
  final _HomeCategory category;
  final bool alternate;
  final VoidCallback onTap;

  const _StayCategoryCard({
    required this.category,
    required this.alternate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageAsset = category.imageAsset;
    return Semantics(
      button: true,
      label: 'Browse ${category.label}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            width: imageAsset == null ? 128 : 148,
            decoration: BoxDecoration(
              gradient: imageAsset == null
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        alternate
                            ? const Color(0xFFF3EFF8)
                            : const Color(0xFFFFE9EE),
                      ],
                    )
                  : null,
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF0E2E6)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: .08),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: imageAsset == null
                ? _GraphicCategoryContent(category: category)
                : _ImageCategoryContent(
                    category: category,
                    imageAsset: imageAsset,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ImageCategoryContent extends StatelessWidget {
  final _HomeCategory category;
  final String imageAsset;

  const _ImageCategoryContent({
    required this.category,
    required this.imageAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(imageAsset, fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xD9232530)],
              stops: [.38, 1],
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .92),
              shape: BoxShape.circle,
            ),
            child: Icon(category.icon, color: AppColors.brand, size: 19),
          ),
        ),
        Positioned(
          left: 14,
          right: 12,
          bottom: 13,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                category.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .78),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GraphicCategoryContent extends StatelessWidget {
  final _HomeCategory category;

  const _GraphicCategoryContent({required this.category});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: .11),
              shape: BoxShape.circle,
            ),
            child: Icon(category.icon, color: AppColors.brand, size: 28),
          ),
          const SizedBox(height: 13),
          Text(
            category.label,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            category.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _HomeReveal extends StatelessWidget {
  final Animation<double> animation;
  final Interval interval;
  final Widget child;
  final double distance;

  const _HomeReveal({
    required this.animation,
    required this.interval,
    required this.child,
    this.distance = 16,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = interval.transform(animation.value);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * distance),
            child: child,
          ),
        );
      },
    );
  }
}

class _PremiumHero extends StatelessWidget {
  final String greeting;
  final String fullName;
  final String? profilePhotoUrl;
  final String locationLabel;
  final bool locating;
  final VoidCallback onMenu;
  final VoidCallback onNotifications;
  final VoidCallback onAccount;
  final VoidCallback onLocation;
  final VoidCallback onSearch;

  const _PremiumHero({
    required this.greeting,
    required this.fullName,
    required this.profilePhotoUrl,
    required this.locationLabel,
    required this.locating,
    required this.onMenu,
    required this.onNotifications,
    required this.onAccount,
    required this.onLocation,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('student-home-hero'),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBFC), Color(0xFFFFEDF1), Color(0xFFF7F3F5)],
          stops: [0, .56, 1],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: .09),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -42,
            top: 62,
            child: Container(
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: .09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 42,
            top: 128,
            child: Transform.rotate(
              angle: -.18,
              child: Container(
                width: 88,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 14,
              20,
              26,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeroIconButton(
                      icon: Icons.menu_rounded,
                      label: 'Open menu',
                      onTap: onMenu,
                    ),
                    const SizedBox(width: 12),
                    const HiPgPlainLogo(fontSize: 23),
                    const Spacer(),
                    _HeroIconButton(
                      icon: Icons.notifications_none_rounded,
                      label: 'Open notifications',
                      onTap: onNotifications,
                    ),
                    const SizedBox(width: 8),
                    _ProfileAvatar(
                      fullName: fullName,
                      photoUrl: profilePhotoUrl,
                      onTap: onAccount,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Material(
                  color: Colors.white.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: locating ? null : onLocation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (locating)
                            const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.brand,
                              ),
                            )
                          else
                            const Icon(
                              Icons.near_me_rounded,
                              size: 16,
                              color: AppColors.brand,
                            ),
                          const SizedBox(width: 7),
                          Text(
                            locating ? 'Finding your area...' : locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 17,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  greeting,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Where should your next chapter begin?',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Material(
                  color: Colors.white,
                  elevation: 0,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const Key('student-home-search'),
                    onTap: onSearch,
                    child: Container(
                      height: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFF1DDE2)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brand.withValues(alpha: .10),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: AppColors.brand,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Search your next stay',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'PGs, areas, cities and budgets',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.ink,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeroIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white.withValues(alpha: .86),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 22, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String fullName;
  final String? photoUrl;
  final VoidCallback onTap;

  const _ProfileAvatar({
    required this.fullName,
    required this.photoUrl,
    required this.onTap,
  });

  Widget _fallback() => Center(
        child: fullName.isEmpty
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 20)
            : Text(
                fullName.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Account',
      child: Material(
        color: AppColors.brand,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: photoUrl == null
                ? _fallback()
                : Image.network(
                    photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(),
                  ),
          ),
        ),
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.verified_rounded, 'Verified', 'Owner checks'),
      (Icons.map_rounded, 'Map-ready', 'Easy routes'),
      (Icons.currency_rupee_rounded, 'Clear rent', 'No guessing'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why residents choose Hi PG',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -.35,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            key: const Key('student-home-trust-strip'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFFFF4F6)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1E2E6)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: .06),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: .11),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            items[index].$1,
                            size: 20,
                            color: AppColors.brand,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          items[index].$2,
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[index].$3,
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index != items.length - 1)
                    Container(width: 1, height: 54, color: AppColors.border),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeRecommendations {
  final List<PgSearchResult> pgs;
  final List<PgSearchResult> nearby;
  final String? city;
  final bool cityFallback;

  const _HomeRecommendations({
    required this.pgs,
    this.nearby = const [],
    this.city,
    this.cityFallback = false,
  });
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
  final _controller = PageController(viewportFraction: .90);
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
          height: 176,
          child: PageView.builder(
            controller: _controller,
            itemCount: _promos.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final promo = _promos[index];
              final dark = promo.background == AppColors.ink;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.onTap,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: dark
                              ? const [Color(0xFF282A38), Color(0xFF3D4053)]
                              : [promo.background, Colors.white],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: dark
                              ? Colors.white.withValues(alpha: .08)
                              : promo.accent.withValues(alpha: .12),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -30,
                            top: -36,
                            child: Container(
                              width: 132,
                              height: 132,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: promo.accent.withValues(alpha: .11),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 19, 18, 19),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: promo.accent.withValues(
                                              alpha: dark ? .20 : .10),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          promo.tag,
                                          style: TextStyle(
                                            color: dark
                                                ? const Color(0xFFFF9AAF)
                                                : promo.accent,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: .75,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        promo.title,
                                        maxLines: 2,
                                        style: TextStyle(
                                          color: promo.foreground,
                                          fontSize: 18,
                                          height: 1.15,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -.45,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        promo.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: promo.foreground
                                              .withValues(alpha: .72),
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 66,
                                  height: 66,
                                  decoration: BoxDecoration(
                                    color: dark
                                        ? AppColors.brand
                                        : Colors.white.withValues(alpha: .92),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            promo.accent.withValues(alpha: .22),
                                        blurRadius: 18,
                                        offset: const Offset(0, 7),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    promo.icon,
                                    size: 31,
                                    color: dark ? Colors.white : promo.accent,
                                  ),
                                ),
                              ],
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

/// Data-backed discovery rows. A row is omitted when the public API returns
/// no matching properties, so the home page never fabricates inventory.
class _DiscoverySections extends StatelessWidget {
  final Future<_HomeRecommendations> future;
  final VoidCallback onSeeAll;
  final ValueChanged<_HomeCategory> onCategory;
  final ValueChanged<PgSearchResult> onOpen;
  final VoidCallback onRetry;

  const _DiscoverySections({
    required this.future,
    required this.onSeeAll,
    required this.onCategory,
    required this.onOpen,
    required this.onRetry,
  });

  static const _cardWidth = 168.0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeRecommendations>(
      future: future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        if (loading) {
          return const _DiscoveryLoadingRail(cardWidth: _cardWidth);
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SizedBox(
              height: 280,
              child: AppErrorView(
                message: 'Property discovery is temporarily unavailable.',
                onRetry: onRetry,
              ),
            ),
          );
        }
        final recommendations = snapshot.data;
        final pgs = recommendations?.pgs ?? const <PgSearchResult>[];
        if (pgs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SizedBox(
              height: 280,
              child: AppEmptyView(
                icon: Icons.apartment_rounded,
                title: 'No PGs to show yet',
                message:
                    'Try another location or browse all currently published listings.',
                actionLabel: 'Browse all PGs',
                onAction: onSeeAll,
              ),
            ),
          );
        }

        final nearby = recommendations?.nearby ?? const <PgSearchResult>[];
        final primary = nearby.isNotEmpty ? nearby : pgs.take(10).toList();
        final primaryTitle = nearby.isNotEmpty
            ? 'PGs within 15 km'
            : recommendations?.city != null
                ? 'PGs in ${recommendations!.city}'
                : 'PGs to explore';

        final collections = <_PropertyCollection>[
          _PropertyCollection(primaryTitle, primary),
          _PropertyCollection(
            'Men\'s PGs',
            pgs
                .where((pg) => pg.genderPreference == GenderPreference.male)
                .toList(),
            category: _HomeCategory.men,
          ),
          _PropertyCollection(
            'Women\'s PGs',
            pgs
                .where((pg) => pg.genderPreference == GenderPreference.female)
                .toList(),
            category: _HomeCategory.women,
          ),
          _PropertyCollection(
            'Co-living spaces',
            pgs
                .where((pg) => pg.genderPreference == GenderPreference.coEd)
                .toList(),
            category: _HomeCategory.coliving,
          ),
          _PropertyCollection(
            'Monthly stays',
            pgs.where((pg) => pg.offersMonthly != false).toList(),
            category: _HomeCategory.monthly,
          ),
          _PropertyCollection(
            'Day-wise stays',
            pgs.where((pg) => pg.offersDayWise == true).toList(),
            category: _HomeCategory.dayWise,
          ),
        ].where((collection) => collection.pgs.isNotEmpty).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < collections.length; index++) ...[
              _PropertyRail(
                collection: collections[index],
                cardWidth: _cardWidth,
                onSeeAll: collections[index].category == null
                    ? onSeeAll
                    : () => onCategory(collections[index].category!),
                onOpen: onOpen,
              ),
              if (index != collections.length - 1)
                const SizedBox(height: AppSpacing.xl),
            ],
          ],
        );
      },
    );
  }
}

class _PropertyCollection {
  final String title;
  final List<PgSearchResult> pgs;
  final _HomeCategory? category;

  const _PropertyCollection(this.title, this.pgs, {this.category});
}

class _PropertyRail extends StatelessWidget {
  final _PropertyCollection collection;
  final double cardWidth;
  final VoidCallback onSeeAll;
  final ValueChanged<PgSearchResult> onOpen;

  const _PropertyRail({
    required this.collection,
    required this.cardWidth,
    required this.onSeeAll,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final visible = collection.pgs.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: SectionHeader(
            title: collection.title,
            actionLabel: 'See all',
            onAction: onSeeAll,
          ),
        ),
        SizedBox(
          height: cardWidth * pgPosterImageHeightRatio +
              MediaQuery.textScalerOf(context).scale(pgPosterTextHeight + 4),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) => PgPosterCard(
              width: cardWidth,
              pg: visible[index],
              onTap: () => onOpen(visible[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiscoveryLoadingRail extends StatelessWidget {
  final double cardWidth;

  const _DiscoveryLoadingRail({required this.cardWidth});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Container(
            width: 150,
            height: 18,
            decoration: const BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadii.small,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: cardWidth * pgPosterImageHeightRatio +
              MediaQuery.textScalerOf(context).scale(pgPosterTextHeight + 4),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, __) => PgPosterSkeleton(width: cardWidth),
          ),
        ),
      ],
    );
  }
}

class _DiscoveryCta extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onBrowse;

  const _DiscoveryCta({required this.onSearch, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        key: const Key('student-home-brand-story'),
        height: 480,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFFDFDFE),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: .07),
              blurRadius: 24,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _HiPgLineArtPainter()),
              ),
            ),
            const Positioned(
              right: -44,
              top: -50,
              child: _StoryGlow(),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'THE HI PG WAY',
                      style: TextStyle(
                        color: AppColors.brandText,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Find your place.\nFeel at home.',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 28,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: 260,
                    child: Text(
                      'Verified stays, clearer choices and routes that take you straight to the door.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.42,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '#findYourHiPG',
                    style: TextStyle(
                      color: AppColors.ink.withValues(alpha: .18),
                      fontSize: 31,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Expanded(
                        child: _StoryFact(
                          icon: Icons.verified_user_rounded,
                          label: 'Verified-first',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _StoryFact(
                          icon: Icons.location_city_rounded,
                          label: 'Made for India',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onSearch,
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Find my stay'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 52,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: onBrowse,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Icon(Icons.grid_view_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryGlow extends StatelessWidget {
  const _StoryGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brand.withValues(alpha: .08),
      ),
    );
  }
}

class _StoryFact extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StoryFact({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.brand, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _HiPgLineArtPainter extends CustomPainter {
  const _HiPgLineArtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink.withValues(alpha: .085)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final soft = Paint()
      ..color = AppColors.brand.withValues(alpha: .075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final skylineY = size.height * .56;
    canvas.drawPath(
      Path()
        ..moveTo(0, skylineY)
        ..lineTo(size.width * .12, skylineY)
        ..lineTo(size.width * .12, skylineY - 48)
        ..lineTo(size.width * .20, skylineY - 48)
        ..lineTo(size.width * .20, skylineY - 78)
        ..lineTo(size.width * .30, skylineY - 78)
        ..lineTo(size.width * .30, skylineY)
        ..lineTo(size.width * .41, skylineY)
        ..lineTo(size.width * .41, skylineY - 36)
        ..lineTo(size.width * .51, skylineY - 36)
        ..lineTo(size.width * .51, skylineY - 92)
        ..lineTo(size.width * .61, skylineY - 92)
        ..lineTo(size.width * .61, skylineY)
        ..lineTo(size.width * .72, skylineY)
        ..lineTo(size.width * .72, skylineY - 62)
        ..lineTo(size.width * .84, skylineY - 62)
        ..lineTo(size.width * .84, skylineY - 24)
        ..lineTo(size.width, skylineY - 24),
      paint,
    );

    for (final x in [.15, .235, .445, .55, .76, .805]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * x, skylineY - 20),
            width: 7,
            height: 12,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }

    final bed = Rect.fromLTWH(
      size.width * .07,
      size.height * .64,
      size.width * .34,
      size.height * .11,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bed, const Radius.circular(10)),
      paint,
    );
    canvas.drawLine(
      Offset(bed.left, bed.bottom),
      Offset(bed.left, bed.bottom + 14),
      paint,
    );
    canvas.drawLine(
      Offset(bed.right, bed.bottom),
      Offset(bed.right, bed.bottom + 14),
      paint,
    );
    canvas.drawLine(
      Offset(bed.left + 12, bed.top + 34),
      Offset(bed.right - 10, bed.top + 34),
      paint,
    );

    final pinCenter = Offset(size.width * .78, size.height * .69);
    final pin = Path()
      ..moveTo(pinCenter.dx, pinCenter.dy + 36)
      ..cubicTo(
        pinCenter.dx - 38,
        pinCenter.dy - 2,
        pinCenter.dx - 26,
        pinCenter.dy - 42,
        pinCenter.dx,
        pinCenter.dy - 42,
      )
      ..cubicTo(
        pinCenter.dx + 26,
        pinCenter.dy - 42,
        pinCenter.dx + 38,
        pinCenter.dy - 2,
        pinCenter.dx,
        pinCenter.dy + 36,
      );
    canvas.drawPath(pin, soft);
    canvas.drawCircle(
      Offset(pinCenter.dx, pinCenter.dy - 15),
      9,
      soft,
    );

    final shieldCenter = Offset(size.width * .55, size.height * .73);
    canvas.drawPath(
      Path()
        ..moveTo(shieldCenter.dx, shieldCenter.dy - 28)
        ..lineTo(shieldCenter.dx + 27, shieldCenter.dy - 17)
        ..lineTo(shieldCenter.dx + 21, shieldCenter.dy + 18)
        ..quadraticBezierTo(
          shieldCenter.dx,
          shieldCenter.dy + 38,
          shieldCenter.dx - 21,
          shieldCenter.dy + 18,
        )
        ..lineTo(shieldCenter.dx - 27, shieldCenter.dy - 17)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(shieldCenter.dx - 11, shieldCenter.dy + 1)
        ..lineTo(shieldCenter.dx - 2, shieldCenter.dy + 10)
        ..lineTo(shieldCenter.dx + 14, shieldCenter.dy - 8),
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * .90, size.height * .44),
      18,
      paint,
    );
    canvas.drawLine(
      Offset(size.width * .90 + 13, size.height * .44 + 13),
      Offset(size.width * .97, size.height * .50),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(size.width * .02, size.height * .83)
        ..cubicTo(
          size.width * .23,
          size.height * .75,
          size.width * .46,
          size.height * .89,
          size.width * .67,
          size.height * .81,
        )
        ..cubicTo(
          size.width * .79,
          size.height * .77,
          size.width * .90,
          size.height * .80,
          size.width,
          size.height * .74,
        ),
      soft,
    );
  }

  @override
  bool shouldRepaint(_HiPgLineArtPainter oldDelegate) => false;
}
