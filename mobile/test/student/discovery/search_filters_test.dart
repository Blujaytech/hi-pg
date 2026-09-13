import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/student/discovery/discovery_models.dart';
import 'package:pg_platform_mobile/student/discovery/search_filters.dart';

PgSearchResult _pg(String name, String address, GenderPreference gender,
    {required int beds, double? minRent, double? maxRent}) {
  return PgSearchResult(
    id: name,
    name: name,
    city: 'Hyderabad',
    address: address,
    description: null,
    genderPreference: gender,
    latitude: null,
    longitude: null,
    availableBeds: beds,
    minRentPerBed: minRent,
    maxRentPerBed: maxRent ?? minRent,
  );
}

// The five PGs in the local dev database.
final _svr = _pg('svr boys luxury pg', 'ameerpet', GenderPreference.male,
    beds: 9, minRent: 6000, maxRent: 10000);
final _metro = _pg('Metro Residency Co-living',
    'Aditya Trade Center Road, Ameerpet', GenderPreference.coEd,
    beds: 4, minRent: 6000);
final _ladies = _pg('Comfort Stay Ladies PG',
    '8-3-231, Yellareddyguda Main Road, Ameerpet', GenderPreference.female,
    beds: 0, minRent: 9000);
final _green = _pg('Green Valley Gents PG',
    '8-2-120, SR Nagar Road, near Ameerpet Metro', GenderPreference.male,
    beds: 4, minRent: 6500, maxRent: 8500);
final _sunrise = _pg('Sunrise Mens PG', '12-3-456, Ameerpet',
    GenderPreference.male,
    beds: 2, minRent: 7500);
final _all = [_svr, _metro, _ladies, _green, _sunrise];

List<String> _names(SearchFilters filters) =>
    filters.apply(_all).map((pg) => pg.name).toList();

void main() {
  test('every typed word must match, in any order and case', () {
    expect(_names(const SearchFilters(query: 'svr luxury boys pg')),
        ['svr boys luxury pg']);
    expect(_names(const SearchFilters(query: 'METRO')),
        ['Metro Residency Co-living', 'Green Valley Gents PG']);
    expect(_names(const SearchFilters(query: 'ameerpet metro')),
        ['Metro Residency Co-living', 'Green Valley Gents PG']);
    expect(_names(const SearchFilters(query: 'hyder')), hasLength(5));
    expect(_names(const SearchFilters(query: 'nowhere')), isEmpty);
    expect(_names(const SearchFilters(query: '  ')), hasLength(5));
  });

  test('gender, availability and budget narrow the list', () {
    expect(_names(const SearchFilters(gender: GenderPreference.female)),
        ['Comfort Stay Ladies PG']);
    expect(_names(const SearchFilters(availableOnly: true)),
        isNot(contains('Comfort Stay Ladies PG')));
    // Budget keeps PGs whose rent range overlaps it.
    expect(
        _names(const SearchFilters(
            budget: RangeValues(SearchFilters.budgetFloor, 6000))),
        ['svr boys luxury pg', 'Metro Residency Co-living']);
    expect(
        _names(const SearchFilters(
            budget: RangeValues(9000, SearchFilters.budgetCeiling))),
        ['svr boys luxury pg', 'Comfort Stay Ladies PG']);
  });

  test('sort orders', () {
    expect(_names(const SearchFilters(sort: SortOption.rentLowToHigh)).last,
        'Comfort Stay Ladies PG');
    expect(_names(const SearchFilters(sort: SortOption.rentHighToLow)).first,
        'svr boys luxury pg');
    expect(_names(const SearchFilters(sort: SortOption.mostBedsFree)).first,
        'svr boys luxury pg');
    expect(_names(const SearchFilters()), _all.map((pg) => pg.name).toList());
  });

  test('filter count and reset keep the search text and sort', () {
    const filters = SearchFilters(
      query: 'ameerpet',
      gender: GenderPreference.male,
      budget: RangeValues(6000, 9000),
      availableOnly: true,
      sort: SortOption.rentLowToHigh,
    );
    expect(filters.activeCount, 3);
    expect(filters.minRent, 6000);
    expect(filters.maxRent, 9000);

    final reset = filters.reset();
    expect(reset.activeCount, 0);
    expect(reset.query, 'ameerpet');
    expect(reset.sort, SortOption.rentLowToHigh);
    expect(const SearchFilters().minRent, isNull);
    expect(const SearchFilters().maxRent, isNull);
  });

  test('nothing typed and no filters counts as an empty search', () {
    expect(const SearchFilters().isEmpty, isTrue);
    expect(const SearchFilters(sort: SortOption.mostBedsFree).isEmpty, isTrue);
    expect(const SearchFilters(query: 'metro').isEmpty, isFalse);
    expect(const SearchFilters(availableOnly: true).isEmpty, isFalse);
  });

  test('popular areas come from addresses and cities, most common first', () {
    expect(popularAreas(_all), ['Hyderabad', 'Ameerpet', 'Ameerpet Metro']);
    expect(popularAreas(_all, limit: 1), ['Hyderabad']);
    expect(popularAreas(const []), isEmpty);
  });
}
