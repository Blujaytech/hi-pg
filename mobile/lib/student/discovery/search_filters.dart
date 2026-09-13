import 'package:flutter/material.dart';

import 'discovery_models.dart';

enum SortOption { recommended, rentLowToHigh, rentHighToLow, mostBedsFree }

extension SortOptionLabel on SortOption {
  String get label => switch (this) {
        SortOption.recommended => 'Recommended',
        SortOption.rentLowToHigh => 'Rent: low to high',
        SortOption.rentHighToLow => 'Rent: high to low',
        SortOption.mostBedsFree => 'Most beds free',
      };
}

/// Everything the customer has chosen on the search screen.
///
/// [matches] mirrors the server's rules -- every typed word must appear in
/// the PG's name, address or city, and a budget must overlap the PG's rent
/// range -- so the list narrows instantly while typing and always agrees
/// with what was typed, even against a server that ignores a parameter.
/// "Available now" and sorting only exist here.
class SearchFilters {
  static const double budgetFloor = 0;
  static const double budgetCeiling = 20000;
  static const RangeValues anyBudget = RangeValues(budgetFloor, budgetCeiling);

  final String query;
  final GenderPreference? gender;
  final RangeValues budget;
  final bool availableOnly;
  final SortOption sort;

  const SearchFilters({
    this.query = '',
    this.gender,
    this.budget = anyBudget,
    this.availableOnly = false,
    this.sort = SortOption.recommended,
  });

  SearchFilters copyWith({
    String? query,
    GenderPreference? gender,
    bool clearGender = false,
    RangeValues? budget,
    bool? availableOnly,
    SortOption? sort,
  }) {
    return SearchFilters(
      query: query ?? this.query,
      gender: clearGender ? null : (gender ?? this.gender),
      budget: budget ?? this.budget,
      availableOnly: availableOnly ?? this.availableOnly,
      sort: sort ?? this.sort,
    );
  }

  /// Clears the filters but keeps what was typed and the sort order.
  SearchFilters reset() => SearchFilters(query: query, sort: sort);

  double? get minRent => budget.start > budgetFloor ? budget.start : null;
  double? get maxRent => budget.end < budgetCeiling ? budget.end : null;
  bool get hasBudget => minRent != null || maxRent != null;

  /// Number shown on the Filters button (typing and sorting don't count).
  int get activeCount =>
      (gender != null ? 1 : 0) + (hasBudget ? 1 : 0) + (availableOnly ? 1 : 0);

  bool get isEmpty => query.trim().isEmpty && activeCount == 0;

  List<String> get words => query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  bool matches(PgSearchResult pg) {
    final text = '${pg.name} ${pg.address} ${pg.city}'.toLowerCase();
    if (!words.every(text.contains)) return false;
    if (gender != null && pg.genderPreference != gender) return false;
    if (availableOnly && pg.availableBeds <= 0) return false;
    if (hasBudget) {
      final low = pg.minRentPerBed;
      if (low == null) return false; // no rent listed can't meet a budget
      final high = pg.maxRentPerBed ?? low;
      final min = minRent;
      final max = maxRent;
      if (min != null && high < min) return false;
      if (max != null && low > max) return false;
    }
    return true;
  }

  List<PgSearchResult> apply(Iterable<PgSearchResult> results) {
    final list = results.where(matches).toList();
    switch (sort) {
      case SortOption.recommended:
        break;
      case SortOption.rentLowToHigh:
        list.sort((a, b) => _compareRent(a.minRentPerBed, b.minRentPerBed));
      case SortOption.rentHighToLow:
        list.sort((a, b) => _compareRent(
            b.maxRentPerBed ?? b.minRentPerBed,
            a.maxRentPerBed ?? a.minRentPerBed));
      case SortOption.mostBedsFree:
        list.sort((a, b) => b.availableBeds.compareTo(a.availableBeds));
    }
    return list;
  }

  /// PGs without a listed rent always sort last.
  static int _compareRent(double? a, double? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}

/// Places to suggest before anything is typed: the last part of each PG's
/// address (usually the locality) and its city, most common first.
List<String> popularAreas(Iterable<PgSearchResult> pgs, {int limit = 6}) {
  final counts = <String, int>{};
  final display = <String, String>{};
  void add(String raw) {
    final area = raw.trim().replaceFirst(
        RegExp(r'^(near|opp\.?|opposite|behind)\s+', caseSensitive: false),
        '');
    // Skip house numbers and fragments that aren't place names.
    if (area.length < 3 || RegExp(r'\d').hasMatch(area)) return;
    final key = area.toLowerCase();
    counts[key] = (counts[key] ?? 0) + 1;
    display.putIfAbsent(key, () => _titleCase(area));
  }

  for (final pg in pgs) {
    add(pg.address.split(',').last);
    add(pg.city);
  }
  final keys = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return keys.take(limit).map((key) => display[key]!).toList();
}

String _titleCase(String text) => text
    .split(RegExp(r'\s+'))
    .map((word) => word.isEmpty
        ? word
        : word[0].toUpperCase() + word.substring(1).toLowerCase())
    .join(' ');
