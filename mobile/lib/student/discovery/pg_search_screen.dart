import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_state.dart';
import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import 'discovery_models.dart';
import 'discovery_repository.dart';
import 'search_filters.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

const _underEightK = RangeValues(SearchFilters.budgetFloor, 8000);

String _genderLabel(GenderPreference gender) => switch (gender) {
      GenderPreference.male => 'Men',
      GenderPreference.female => 'Women',
      GenderPreference.coEd => 'Co-ed',
    };

String _budgetLabel(RangeValues budget) {
  final start = budget.start > SearchFilters.budgetFloor;
  final end = budget.end < SearchFilters.budgetCeiling;
  if (!start && !end) return 'Any budget';
  if (!start) return 'Up to ${_money.format(budget.end)}';
  if (!end) return '${_money.format(budget.start)} and above';
  return '${_money.format(budget.start)} – ${_money.format(budget.end)}';
}

/// PG search: one box that narrows results as you type (area, PG name or
/// city), quick filter chips, a full Filters sheet and a Sort menu.
class PgSearchScreen extends StatefulWidget {
  const PgSearchScreen({super.key});

  @override
  State<PgSearchScreen> createState() => _PgSearchScreenState();
}

class _PgSearchScreenState extends State<PgSearchScreen> {
  final _repository = DiscoveryRepository();
  final _queryController = TextEditingController();
  Timer? _debounce;
  SearchFilters _filters = const SearchFilters();

  /// Everything fetched so far; what's shown is `_filters.apply(_loaded)`.
  List<PgSearchResult> _loaded = const [];
  int _page = 0;
  int _totalPages = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _generation = 0;

  /// Results only show once something is searched or filtered, unless
  /// the customer asks to browse everything.
  bool _browseAll = false;

  /// Kept for the app session so the start page can offer them again.
  static final List<String> _recentSearches = [];

  bool get _showResults => _browseAll || !_filters.isEmpty;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  bool get _hasMore => _page + 1 < _totalPages;

  Future<PagedResult<PgSearchResult>> _fetch(int page) => _repository.search(
        query: _filters.query,
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

  Future<void> _openFilters() async {
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _FiltersSheet(initial: _filters),
    );
    if (result != null && mounted) _update(result);
  }

  Future<void> _openSort() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<SortOption>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text('Sort by',
                    style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
              for (final option in SortOption.values)
                _OptionTile(
                  label: option.label,
                  selected: _filters.sort == option,
                  onTap: () => Navigator.pop(sheetContext, option),
                ),
            ],
          ),
        ),
      ),
    );
    // Sorting reorders what's loaded; no need to ask the server again.
    if (picked != null && mounted) {
      _update(_filters.copyWith(sort: picked), refetch: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filters.apply(_loaded);
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
      appBar: _exploreAppBar(context),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: (text) {
                _rememberSearch(text);
                _search();
              },
              decoration: InputDecoration(
                hintText: 'Search area, PG name or city',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _queryController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _clearQuery,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _QuickFilter(
                  label: 'Filters',
                  leading: Icons.tune_rounded,
                  selected: _filters.activeCount > 0,
                  badge: _filters.activeCount,
                  onTap: _openFilters,
                ),
                const SizedBox(width: 8),
                _QuickFilter(
                  label: _filters.sort == SortOption.recommended
                      ? 'Sort'
                      : _filters.sort.label,
                  leading: Icons.swap_vert_rounded,
                  trailing: Icons.expand_more_rounded,
                  selected: _filters.sort != SortOption.recommended,
                  onTap: _openSort,
                ),
                Container(
                  width: 1,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: AppColors.border,
                ),
                _QuickFilter(
                  label: 'Available now',
                  selected: _filters.availableOnly,
                  onTap: () => _update(
                    _filters.copyWith(availableOnly: !_filters.availableOnly),
                    refetch: false,
                  ),
                ),
                for (final gender in GenderPreference.values) ...[
                  const SizedBox(width: 8),
                  _QuickFilter(
                    label: _genderLabel(gender),
                    selected: _filters.gender == gender,
                    onTap: () => _toggleGender(gender),
                  ),
                ],
                const SizedBox(width: 8),
                _QuickFilter(
                  label: 'Under ₹8k',
                  selected: _filters.budget == _underEightK,
                  onTap: () => _update(_filters.copyWith(
                    budget: _filters.budget == _underEightK
                        ? SearchFilters.anyBudget
                        : _underEightK,
                  )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _showResults ? _buildResults(visible) : _buildStartPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildStartPage() {
    final textTheme = Theme.of(context).textTheme;
    final areas = popularAreas(_loaded);
    final total = _hasMore ? '${_loaded.length}+' : '${_loaded.length}';
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text('Where do you want to stay?', style: textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Search an area, PG name or city, or pick a filter above.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        if (_recentSearches.isNotEmpty) ...[
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                  child: Text('Recent searches', style: textTheme.titleSmall)),
              TextButton(
                onPressed: () => setState(_recentSearches.clear),
                child: const Text('Clear'),
              ),
            ],
          ),
          for (final query in _recentSearches)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.history_rounded, color: AppColors.muted),
              title: Text(query),
              trailing: const Icon(Icons.north_west_rounded,
                  size: 18, color: AppColors.subtle),
              onTap: () => _searchFor(query),
            ),
        ],
        if (areas.isNotEmpty) ...[
          const SizedBox(height: 26),
          Text('Popular areas', style: textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final area in areas)
                _QuickFilter(
                  label: area,
                  leading: Icons.place_outlined,
                  selected: false,
                  onTap: () => _searchFor(area),
                ),
            ],
          ),
        ],
        const SizedBox(height: 30),
        OutlinedButton.icon(
          onPressed: () => setState(() => _browseAll = true),
          icon: const Icon(Icons.apartment_rounded, size: 19),
          label: Text(
              _loaded.isEmpty ? 'Browse all PGs' : 'Browse all $total PGs'),
        ),
      ],
    );
  }

  Widget _buildResults(List<PgSearchResult> visible) {
    if (_loading && _loaded.isEmpty) {
      return const AppLoadingView(label: 'Finding stays...');
    }
    if (_error != null) {
      return AppErrorView(message: _error!, onRetry: _search);
    }
    final query = _filters.query.trim();
    if (visible.isEmpty && !_hasMore) {
      return AppEmptyView(
        icon: Icons.search_off_rounded,
        title: query.isEmpty
            ? 'No PGs match these filters'
            : 'No PGs match "$query"',
        message: 'Try an area, PG name or city, or loosen a filter.',
        actionLabel: _filters.isEmpty ? null : 'Clear all',
        actionIcon: Icons.close_rounded,
        onAction: _filters.isEmpty ? null : _clearAll,
      );
    }
    return RefreshIndicator(
      onRefresh: _search,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        itemCount: visible.length + 2,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            final count = '${visible.length}${_hasMore ? '+' : ''}';
            return Row(
              children: [
                Expanded(
                  child: Text(
                    '$count ${visible.length == 1 && !_hasMore ? 'stay' : 'stays'}'
                    '${query.isEmpty ? '' : ' for "$query"'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (!_filters.isEmpty)
                  TextButton(
                      onPressed: _clearAll, child: const Text('Clear all')),
              ],
            );
          }
          if (index == visible.length + 1) {
            if (!_hasMore) return const SizedBox.shrink();
            return OutlinedButton(
              onPressed: _loadingMore ? null : _loadMore,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              child: _loadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Show more'),
            );
          }
          return _PgResultCard(
            pg: visible[index - 1],
            onOpen: () => _rememberSearch(_filters.query),
          );
        },
      ),
    );
  }
}

/// Full filter panel. Edits a draft; nothing changes until "Show results".
class _FiltersSheet extends StatefulWidget {
  final SearchFilters initial;

  const _FiltersSheet({required this.initial});

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
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
  final IconData? trailing;
  final int badge;
  final VoidCallback onTap;

  const _QuickFilter({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.trailing,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.ink;
    return Material(
      color: selected ? AppColors.ink : AppColors.fill,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              leading == null ? 16 : 12, 9, trailing == null ? 16 : 10, 9),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 2),
                Icon(trailing, size: 18, color: foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.ink)
          : null,
      onTap: onTap,
    );
  }
}

class _PgResultCard extends StatelessWidget {
  final PgSearchResult pg;
  final VoidCallback? onOpen;

  const _PgResultCard({required this.pg, this.onOpen});

  String _rentLabel() {
    final min = pg.minRentPerBed;
    if (min == null) return 'Rent on request';
    final max = pg.maxRentPerBed;
    return max == null || max == min
        ? '${_money.format(min)}/mo'
        : 'from ${_money.format(min)}';
  }

  @override
  Widget build(BuildContext context) {
    final available = pg.availableBeds > 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          onOpen?.call();
          context.push('${_detailsBase(context)}/${pg.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: pg.photoUrl == null
                    ? Container(
                        width: 56,
                        height: 68,
                        color: AppColors.ink,
                        child: const Icon(Icons.apartment_rounded,
                            color: Colors.white, size: 26),
                      )
                    : Image.network(
                        pg.photoUrl!,
                        width: 56,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 56,
                          height: 68,
                          color: AppColors.ink,
                          child: const Icon(Icons.apartment_rounded,
                              color: Colors.white, size: 26),
                        ),
                      ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pg.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 15, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${pg.address}, ${pg.city}',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              StatusPill(
                                  label: _genderLabel(pg.genderPreference)),
                              StatusPill(
                                label: available
                                    ? '${pg.availableBeds} ${pg.availableBeds == 1 ? 'bed' : 'beds'} free'
                                    : 'Full',
                                tone: available
                                    ? StatusTone.success
                                    : StatusTone.neutral,
                                dot: available,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _rentLabel(),
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
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
      ),
    );
  }
}

/// Guests reach search from the welcome screen (`/explore`) without an
/// account, so they get a back arrow and a sign-in shortcut instead of tabs.
PreferredSizeWidget _exploreAppBar(BuildContext context) {
  final guestMode = _isGuestExplore(context);
  final signedIn =
      context.watch<AuthState>().status == AuthStatus.authenticated;
  return AppBar(
    title: const Text('Explore'),
    actions: [
      if (guestMode)
        TextButton(
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

bool _isGuestExplore(BuildContext context) =>
    GoRouterState.of(context).matchedLocation.startsWith('/explore');

String _detailsBase(BuildContext context) =>
    _isGuestExplore(context) ? '/explore/pgs' : '/student/pgs';
