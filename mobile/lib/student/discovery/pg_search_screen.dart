import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_state.dart';
import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import 'city_picker_sheet.dart';
import 'discovery_models.dart';
import 'discovery_repository.dart';
import 'location_lookup.dart';
import 'location_preference_store.dart';
import 'pg_poster_card.dart';
import 'search_filters.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

String _genderLabel(GenderPreference gender) => switch (gender) {
      GenderPreference.male => 'Men',
      GenderPreference.female => 'Women',
      GenderPreference.coEd => 'Co-Living',
      GenderPreference.unspecified => 'Unspecified',
    };

String _budgetLabel(RangeValues budget) {
  final start = budget.start > SearchFilters.budgetFloor;
  final end = budget.end < SearchFilters.budgetCeiling;
  if (!start && !end) return 'Any budget';
  if (!start) return 'Up to ${_money.format(budget.end)}';
  if (!end) return '${_money.format(budget.start)} and above';
  return '${_money.format(budget.start)} – ${_money.format(budget.end)}';
}

/// PG search: a location (all cities, one city, or near me) chosen from the
/// header or the pin in the search box, one box that narrows results as you
/// type (area, PG name or pincode), focused gender chips and a full Filters
/// sheet.
class PgSearchScreen extends StatefulWidget {
  /// Injectable for tests; defaults to the public discovery API.
  final DiscoveryRepository? repository;
  final bool browseAll;
  final GenderPreference? initialGender;
  final StayType initialStayType;

  const PgSearchScreen({
    super.key,
    this.repository,
    this.browseAll = false,
    this.initialGender,
    this.initialStayType = StayType.any,
  });

  @override
  State<PgSearchScreen> createState() => _PgSearchScreenState();
}

class _PgSearchScreenState extends State<PgSearchScreen> {
  /// "Near me" keeps PGs within this straight-line distance.
  static const double _nearRadiusKm = 15;

  late final DiscoveryRepository _repository =
      widget.repository ?? DiscoveryRepository();
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  late SearchFilters _filters;

  /// Everything fetched so far; what's shown is `_filters.apply(_loaded)`.
  List<PgSearchResult> _loaded = const [];
  int _page = 0;
  int _totalPages = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _generation = 0;

  /// Results only show once something is searched, filtered or a place is
  /// chosen, unless the customer asks to browse everything.
  bool _browseAll = false;
  bool _locating = false;

  // Kept for the app session so leaving and coming back to Explore keeps the
  // customer's place and history.
  static final List<String> _recentSearches = [];
  static LocationChoice _location = const LocationChoice.allCities();
  static double? _latitude;
  static double? _longitude;
  String? _nearbyFallbackCity;
  final _locationStore = LocationPreferenceStore();

  bool get _nearMe =>
      _location.nearMe && _latitude != null && _longitude != null;

  bool get _showResults =>
      _browseAll || !_filters.isEmpty || _nearMe || _location.city != null;

  @override
  void initState() {
    super.initState();
    _filters = SearchFilters(
      gender: widget.initialGender,
      stayType: widget.initialStayType,
    );
    _browseAll = widget.browseAll;
    _scrollController.addListener(_loadMoreNearBottom);
    _restoreLocation();
  }

  Future<void> _restoreLocation() async {
    if (_location.nearMe && !_nearMe) {
      _location = const LocationChoice.allCities();
    }
    final saved = await _locationStore.read();
    if (!mounted) return;
    if (saved.nearMe) {
      _latitude = saved.latitude;
      _longitude = saved.longitude;
      _nearbyFallbackCity =
          nearestListedCity(saved.latitude!, saved.longitude!);
      _location = const LocationChoice.nearMe();
    } else if (saved.city != null) {
      _latitude = null;
      _longitude = null;
      _location = LocationChoice.city(saved.city!);
    }
    await _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMoreNearBottom() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 500) {
      _loadMore();
    }
  }

  bool get _hasMore => _page + 1 < _totalPages;

  Future<PagedResult<PgSearchResult>> _fetch(int page) => _repository.search(
        query: _filters.query,
        city: _nearMe ? _nearbyFallbackCity : _location.city,
        genderPreference: _filters.gender,
        minRent: _filters.minRent,
        maxRent: _filters.maxRent,
        page: page,
      );

  Future<void> _search() async {
    _debounce?.cancel();
    // Typing fires several searches; only the newest one may update the list.
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _fetch(0);
      if (!mounted || generation != _generation) return;
      setState(() {
        _loaded = result.content;
        _page = result.page;
        _totalPages = result.totalPages;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Could not load PGs right now.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final result = await _fetch(_page + 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _loaded = [..._loaded, ...result.content];
        _page = result.page;
        _totalPages = result.totalPages;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is ApiException
              ? error.message
              : 'Could not load more PGs.')));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Applies [next] instantly to what's on screen; [refetch] also asks the
  /// server when the change affects which PGs it returns.
  void _update(SearchFilters next, {bool refetch = true}) {
    setState(() => _filters = next);
    if (refetch) _search();
  }

  void _onQueryChanged(String text) {
    setState(() => _filters = _filters.copyWith(query: text));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  void _rememberSearch(String text) {
    final query = text.trim();
    if (query.isEmpty) return;
    _recentSearches
      ..removeWhere((q) => q.toLowerCase() == query.toLowerCase())
      ..insert(0, query);
    if (_recentSearches.length > 5) _recentSearches.removeLast();
  }

  void _searchFor(String text) {
    FocusScope.of(context).unfocus();
    _queryController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _rememberSearch(text);
    _update(_filters.copyWith(query: text));
  }

  void _clearQuery() {
    _queryController.clear();
    _update(_filters.copyWith(query: ''));
  }

  void _clearAll() {
    _queryController.clear();
    _browseAll = false;
    _update(SearchFilters(sort: _filters.sort));
  }

  void _toggleGender(GenderPreference gender) =>
      _update(_filters.gender == gender
          ? _filters.copyWith(clearGender: true)
          : _filters.copyWith(gender: gender));

  void _toggleStayType(StayType type) => _update(
        _filters.copyWith(
            stayType: _filters.stayType == type ? StayType.any : type),
        refetch: false,
      );

  Future<void> _setLocation(LocationChoice choice) async {
    if (choice.sameAs(_location) && !choice.nearMe) return;
    setState(() => _location = choice);
    if (choice.city != null) {
      _latitude = null;
      _longitude = null;
      _nearbyFallbackCity = null;
      await _locationStore.saveCity(choice.city!);
    } else if (!choice.nearMe) {
      _latitude = null;
      _longitude = null;
      _nearbyFallbackCity = null;
      await _locationStore.saveDismissed();
    }
    await _search();
  }

  Future<void> _chooseLocation() async {
    FocusScope.of(context).unfocus();
    final picked = await showCityPicker(
      context,
      current: _nearMe ? const LocationChoice.nearMe() : _location,
    );
    if (picked == null || !mounted) return;
    if (picked.nearMe) {
      await _useNearMe();
    } else {
      await _setLocation(picked);
    }
  }

  Future<void> _useNearMe() async {
    if (_locating) return;
    FocusScope.of(context).unfocus();
    setState(() => _locating = true);
    final lookup = await lookUpLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (!lookup.ok) {
      _explainLocationProblem(lookup.problem!);
      return;
    }
    _latitude = lookup.position!.latitude;
    _longitude = lookup.position!.longitude;
    _nearbyFallbackCity = nearestListedCity(_latitude!, _longitude!);
    await _locationStore.saveNearMe(_latitude!, _longitude!);
    await _setLocation(const LocationChoice.nearMe());
  }

  void _explainLocationProblem(LocationProblem problem) {
    final (message, action, onAction) = switch (problem) {
      LocationProblem.serviceOff => (
          'Turn on location to see PGs near you.',
          'Turn on',
          Geolocator.openLocationSettings,
        ),
      LocationProblem.deniedForever => (
          'Location access is off for hi pg. Allow it in settings to see PGs near you.',
          'Settings',
          Geolocator.openAppSettings,
        ),
      LocationProblem.denied => (
          'Allow location access to see PGs near you, or pick your city instead.',
          'Pick city',
          () async {
            await _chooseLocation();
            return true;
          },
        ),
      LocationProblem.unavailable => (
          "Couldn't find your location right now. Try again, or pick your city.",
          'Pick city',
          () async {
            await _chooseLocation();
            return true;
          },
        ),
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      action: SnackBarAction(label: action, onPressed: () => onAction()),
    ));
  }

  Future<void> _openFilters() async {
    FocusScope.of(context).unfocus();
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final Future<SearchFilters?> resultFuture;
    if (compact) {
      resultFuture = showModalBottomSheet<SearchFilters>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _FiltersSheet(initial: _filters),
      );
    } else {
      final panelWidth =
          MediaQuery.sizeOf(context).width < 1000 ? 420.0 : 460.0;
      resultFuture = showGeneralDialog<SearchFilters>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close filters',
        barrierColor: Colors.black54,
        transitionDuration: AppDurations.standard,
        pageBuilder: (dialogContext, _, __) => Align(
          alignment: Alignment.centerRight,
          child: SafeArea(
            child: Material(
              color: AppColors.surface,
              elevation: 16,
              child: SizedBox(
                width: panelWidth,
                height: double.infinity,
                child: _FiltersSheet(
                  initial: _filters,
                  showClose: true,
                ),
              ),
            ),
          ),
        ),
        transitionBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
      );
    }
    final result = await resultFuture;
    if (result != null && mounted) _update(result);
  }

  /// What's on screen, plus each PG's distance when searching near the
  /// customer (PGs without a map pin can't be placed, so they're left out).
  (List<PgSearchResult>, Map<String, double>, bool) _visible() {
    final list = _filters.apply(_loaded);
    final latitude = _latitude;
    final longitude = _longitude;
    if (!_nearMe || latitude == null || longitude == null) {
      return (list, const {}, false);
    }
    final distances = <String, double>{};
    for (final pg in list) {
      if (pg.latitude == null || pg.longitude == null) continue;
      final km = distanceKm(latitude, longitude, pg.latitude!, pg.longitude!);
      if (km <= _nearRadiusKm) distances[pg.id] = km;
    }
    final near = list.where((pg) => distances.containsKey(pg.id)).toList();
    if (_filters.sort == SortOption.recommended) {
      near.sort((a, b) => distances[a.id]!.compareTo(distances[b.id]!));
    }
    if (near.isNotEmpty) return (near, distances, false);
    final cityFallback = list
        .where((pg) => pg.latitude == null || pg.longitude == null)
        .toList();
    return (cityFallback, const {}, cityFallback.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final (visible, distances, cityFallback) = _visible();
    // Keep filling the list when local filters leave too little on screen.
    if (_showResults &&
        !_loading &&
        !_loadingMore &&
        _error == null &&
        _hasMore &&
        visible.length < 8) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
    }
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: _appBar(),
      body: Column(
        children: [
          _SearchBand(
            controller: _queryController,
            hint: _nearMe
                ? 'Search PGs near you'
                : _location.city != null
                    ? 'Search areas or PGs in ${_location.city}'
                    : 'Search area, PG name or pincode',
            locating: _locating,
            onChanged: _onQueryChanged,
            onSubmitted: (text) {
              _rememberSearch(text);
              _search();
            },
            onClear: _clearQuery,
            onPickLocation: _chooseLocation,
          ),
          Container(
            height: 66,
            color: AppColors.canvas,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              children: [
                _QuickFilter(
                  label: 'Filters',
                  leading: Icons.tune_rounded,
                  selected: _filters.activeCount > 0,
                  badge: _filters.activeCount,
                  onTap: _openFilters,
                ),
                if (_showResults) ...[
                  const SizedBox(width: 8),
                  _QuickFilter(
                    label: 'Monthly',
                    selected: _filters.stayType == StayType.monthly,
                    onTap: () => _toggleStayType(StayType.monthly),
                  ),
                  const SizedBox(width: 8),
                  _QuickFilter(
                    label: 'Day-wise',
                    selected: _filters.stayType == StayType.dayWise,
                    onTap: () => _toggleStayType(StayType.dayWise),
                  ),
                ],
                for (final gender in GenderPreference.values) ...[
                  const SizedBox(width: 8),
                  _QuickFilter(
                    label: _genderLabel(gender),
                    selected: _filters.gender == gender,
                    onTap: () => _toggleGender(gender),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _showResults
                ? _buildResults(visible, distances, cityFallback)
                : _buildStartPage(),
          ),
        ],
      ),
    );
  }

  /// Guests reach search from the welcome screen (`/explore`) without an
  /// account, so they get a back arrow and a sign-in shortcut instead of
  /// tabs. The title doubles as the location switcher.
  PreferredSizeWidget _appBar() {
    final guestMode = _isGuestExplore(context);
    final signedIn =
        context.watch<AuthState>().status == AuthStatus.authenticated;
    return AppBar(
      backgroundColor: const Color(0xFFFFFAFB),
      foregroundColor: AppColors.ink,
      systemOverlayStyle: AppTheme.lightChrome,
      title: Semantics(
        button: true,
        label: 'Location: ${_nearMe ? 'near you' : _location.label}. Change',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: _chooseLocation,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Explore stays',
                    style: TextStyle(color: AppColors.ink),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _nearMe
                            ? Icons.my_location_rounded
                            : Icons.location_on_rounded,
                        size: 14,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _nearMe ? 'Near you' : _location.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const Icon(Icons.expand_more_rounded,
                          size: 16, color: AppColors.muted),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        if (guestMode)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.brandText),
            onPressed: () {
              if (signedIn) {
                context.go('/student');
              } else {
                context.push('/student/login');
              }
            },
            child: Text(signedIn ? 'My account' : 'Sign in'),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStartPage() {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
      children: [
        Text(
          'Find a stay that fits you',
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 5),
        Text(
          'Choose your stay style, then discover verified options.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 126,
                child: _StayTypeCard(
                  icon: Icons.calendar_month_rounded,
                  title: 'Monthly',
                  subtitle: 'Your everyday home',
                  onTap: () {
                    _browseAll = true;
                    _toggleStayType(StayType.monthly);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 126,
                child: _StayTypeCard(
                  icon: Icons.nights_stay_rounded,
                  title: 'Day-wise',
                  subtitle: 'Flexible short stays',
                  onTap: () {
                    _browseAll = true;
                    _toggleStayType(StayType.dayWise);
                  },
                ),
              ),
            ),
          ],
        ),
        if (_recentSearches.isNotEmpty) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                  child: Text('Recent searches', style: textTheme.titleMedium)),
              TextButton(
                onPressed: () => setState(_recentSearches.clear),
                child: const Text('Clear'),
              ),
            ],
          ),
          for (final query in _recentSearches) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const IconTile(
                  icon: Icons.history_rounded,
                  size: 38,
                  color: AppColors.brand,
                  background: AppColors.brandSoft,
                ),
                title: Text(query),
                trailing: const Icon(Icons.north_west_rounded,
                    size: 18, color: AppColors.subtle),
                onTap: () => _searchFor(query),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildResults(List<PgSearchResult> visible,
      Map<String, double> distances, bool cityFallback) {
    if (_loading && _loaded.isEmpty) {
      return AppLoadingView(
          label: _nearMe ? 'Finding stays near you...' : 'Finding stays...');
    }
    if (_error != null) {
      return AppErrorView(message: _error!, onRetry: _search);
    }
    final query = _filters.query.trim();
    if (visible.isEmpty && !_hasMore) {
      if (_nearMe && _filters.isEmpty) {
        return AppEmptyView(
          icon: Icons.location_searching_rounded,
          title: 'No PGs within ${_nearRadiusKm.round()} km of you yet',
          message: 'Pick your city to see every PG listed there.',
          actionLabel: 'Pick city',
          actionIcon: Icons.location_city_rounded,
          onAction: _chooseLocation,
        );
      }
      return AppEmptyView(
        icon: Icons.search_off_rounded,
        title: query.isEmpty
            ? 'No PGs match these filters'
            : 'No PGs match "$query"',
        message: _location.city != null
            ? 'Try another area of ${_location.city}, loosen a filter, or change the city.'
            : 'Try an area, PG name or pincode, or loosen a filter.',
        actionLabel: _filters.isEmpty ? 'Change city' : 'Clear filters',
        actionIcon: _filters.isEmpty
            ? Icons.location_city_rounded
            : Icons.close_rounded,
        onAction: _filters.isEmpty ? _chooseLocation : _clearAll,
      );
    }
    final count = '${visible.length}${_hasMore ? '+' : ''}';
    final where = _nearMe
        ? cityFallback && _nearbyFallbackCity != null
            ? ' in $_nearbyFallbackCity'
            : ' within ${_nearRadiusKm.round()} km'
        : _location.city != null
            ? ' in ${_location.city}'
            : '';
    return RefreshIndicator(
      onRefresh: _search,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          if (cityFallback)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 17,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing ${_nearbyFallbackCity ?? 'city'} stays while nearby map coverage improves.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                    fontSize: 11.5,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$count ${visible.length == 1 && !_hasMore ? 'stay' : 'stays'}'
                        '${query.isEmpty ? where : ' for "$query"$where'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.crossAxisExtent >= 900
                    ? 4
                    : constraints.crossAxisExtent >= 640
                        ? 3
                        : 2;
                const gap = 12.0;
                final cardWidth =
                    (constraints.crossAxisExtent - (gap * (columns - 1))) /
                        columns;
                final textHeight = MediaQuery.textScalerOf(context)
                    .scale(pgPosterTextHeight + 6);
                final cardHeight =
                    (cardWidth * pgPosterImageHeightRatio) + textHeight;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    childAspectRatio: cardWidth / cardHeight,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final pg = visible[index];
                      return _SearchResultReveal(
                        index: index,
                        child: PgPosterCard(
                          pg: pg,
                          distanceKm: distances[pg.id],
                          onTap: () {
                            _rememberSearch(_filters.query);
                            final type = switch (_filters.stayType) {
                              StayType.monthly => 'MONTHLY',
                              StayType.dayWise => 'DAY_WISE',
                              StayType.any => null,
                            };
                            context.push(Uri(
                              path: '${_detailsBase(context)}/${pg.id}',
                              queryParameters:
                                  type == null ? null : {'stayType': type},
                            ).toString());
                          },
                        ),
                      );
                    },
                    childCount: visible.length,
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            sliver: SliverToBoxAdapter(
              child: !_hasMore
                  ? const SizedBox.shrink()
                  : OutlinedButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                      child: _loadingMore
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Show more'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultReveal extends StatelessWidget {
  final int index;
  final Widget child;

  const _SearchResultReveal({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + ((index % 6) * 45)),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

/// Premium discovery hero with the same warm visual language as home.
class _SearchBand extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool locating;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onPickLocation;

  const _SearchBand({
    required this.controller,
    required this.hint,
    required this.locating,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onPickLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFAFB), Color(0xFFFFE9EE)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where do you want to stay?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppShadows.card,
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                decoration: InputDecoration(
                  hintText: hint,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                    borderSide: BorderSide(color: AppColors.brand, width: 1.2),
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircleAvatar(
                      backgroundColor: AppColors.brand,
                      child: Icon(Icons.search_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (value.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: onClear,
                        ),
                      Container(width: 1, height: 24, color: AppColors.border),
                      IconButton(
                        tooltip: 'Choose city or use your location',
                        onPressed: onPickLocation,
                        icon: locating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded,
                                color: AppColors.brand),
                      ),
                      const SizedBox(width: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StayTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _StayTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: AppColors.ink.withValues(alpha: .12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.brand, size: 22),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full filter panel. Edits a draft; nothing changes until "Show results".
class _FiltersSheet extends StatefulWidget {
  final SearchFilters initial;
  final bool showClose;

  const _FiltersSheet({required this.initial, this.showClose = false});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late SearchFilters _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final budget = _draft.budget;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              children: [
                Expanded(child: Text('Filters', style: textTheme.titleLarge)),
                TextButton(
                  onPressed: _draft.activeCount == 0
                      ? null
                      : () => setState(() => _draft = _draft.reset()),
                  child: const Text('Reset'),
                ),
                if (widget.showClose)
                  IconButton(
                    tooltip: 'Close filters',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stay type', style: textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in StayType.values)
                        _QuickFilter(
                          label: type == StayType.any ? 'Any' : type.label,
                          selected: _draft.stayType == type,
                          onTap: () => setState(
                              () => _draft = _draft.copyWith(stayType: type)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text('PG for', style: textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QuickFilter(
                        label: 'Any',
                        selected: _draft.gender == null,
                        onTap: () => setState(
                            () => _draft = _draft.copyWith(clearGender: true)),
                      ),
                      for (final gender in GenderPreference.values)
                        _QuickFilter(
                          label: _genderLabel(gender),
                          selected: _draft.gender == gender,
                          onTap: () => setState(
                              () => _draft = _draft.copyWith(gender: gender)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Budget per bed / month',
                            style: textTheme.titleSmall),
                      ),
                      Text(_budgetLabel(budget),
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  RangeSlider(
                    values: budget,
                    min: SearchFilters.budgetFloor,
                    max: SearchFilters.budgetCeiling,
                    divisions: 40,
                    labels: RangeLabels(
                      _money.format(budget.start),
                      budget.end >= SearchFilters.budgetCeiling
                          ? '₹20k+'
                          : _money.format(budget.end),
                    ),
                    onChanged: (value) =>
                        setState(() => _draft = _draft.copyWith(budget: value)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₹0', style: textTheme.bodySmall),
                      Text('₹20,000+', style: textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('Availability', style: textTheme.titleSmall),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Only PGs with free beds'),
                    subtitle: const Text('Hide PGs that are currently full'),
                    value: _draft.availableOnly,
                    onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(availableOnly: value)),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _draft),
              child: Text(_draft.activeCount == 0
                  ? 'Show results'
                  : 'Show results · ${_draft.activeCount} filter${_draft.activeCount == 1 ? '' : 's'}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickFilter extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? leading;
  final int badge;
  final VoidCallback onTap;

  const _QuickFilter({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.brandText : AppColors.ink;
    return Material(
      color: selected ? AppColors.brandSoft : AppColors.surface,
      elevation: selected ? 0 : .5,
      shadowColor: AppColors.ink.withValues(alpha: .10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppColors.brand : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(leading == null ? 14 : 10, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                Icon(leading, size: 17, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

bool _isGuestExplore(BuildContext context) =>
    GoRouterState.of(context).matchedLocation.startsWith('/explore');

String _detailsBase(BuildContext context) =>
    _isGuestExplore(context) ? '/explore/pgs' : '/student/pgs';
