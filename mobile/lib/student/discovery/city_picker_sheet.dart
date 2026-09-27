import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../owner/pg/supported_cities.dart';

/// Where the customer wants to look: everywhere, one city, or around them.
class LocationChoice {
  final String? city;
  final bool nearMe;

  const LocationChoice.allCities()
      : city = null,
        nearMe = false;
  const LocationChoice.city(String this.city) : nearMe = false;
  const LocationChoice.nearMe()
      : city = null,
        nearMe = true;

  String get label => nearMe ? 'Near you' : city ?? 'All cities';

  bool sameAs(LocationChoice other) =>
      nearMe == other.nearMe &&
      (city ?? '').toLowerCase() == (other.city ?? '').toLowerCase();
}

/// Opens a validated city picker. Only the curated Indian city list is shown;
/// typing narrows that same list. Returns null if dismissed.
Future<LocationChoice?> showCityPicker(
  BuildContext context, {
  required LocationChoice current,
}) {
  return showModalBottomSheet<LocationChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: .9,
      child: _CityPicker(current: current),
    ),
  );
}

class _CityPicker extends StatefulWidget {
  final LocationChoice current;

  const _CityPicker({required this.current});

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matches(String city) =>
      _query.isEmpty || city.toLowerCase().contains(_query.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cities = supportedIndianCities.where(_matches).toList();
    final typed = _query.trim();

    void pick(LocationChoice choice) => Navigator.of(context).pop(choice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Select your city', style: textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.words,
            onChanged: (value) => setState(() => _query = value.trim()),
            onSubmitted: (value) {
              final query = value.trim().toLowerCase();
              if (query.isEmpty) return;
              final matches = supportedIndianCities
                  .where((city) => city.toLowerCase() == query);
              if (matches.isNotEmpty) {
                pick(LocationChoice.city(matches.first));
              }
            },
            decoration: const InputDecoration(
              hintText: 'Search for your city',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (typed.isEmpty) ...[
                _PickerTile(
                  icon: Icons.my_location_rounded,
                  iconColor: AppColors.brand,
                  title: 'Use my current location',
                  subtitle: 'PGs and hostels near you',
                  selected: widget.current.nearMe,
                  onTap: () => pick(const LocationChoice.nearMe()),
                ),
                _PickerTile(
                  icon: Icons.public_rounded,
                  title: 'All cities',
                  selected:
                      !widget.current.nearMe && widget.current.city == null,
                  onTap: () => pick(const LocationChoice.allCities()),
                ),
                const Divider(height: 16),
              ],
              if (cities.isNotEmpty) ...[
                const _SectionLabel('MAJOR CITIES IN INDIA'),
                for (final city in cities)
                  _PickerTile(
                    icon: Icons.location_city_rounded,
                    title: city,
                    selected: _isCurrent(city),
                    onTap: () => pick(LocationChoice.city(city)),
                  ),
              ] else if (typed.isNotEmpty) ...[
                const SizedBox(height: 36),
                const Icon(Icons.location_off_outlined,
                    size: 34, color: AppColors.subtle),
                const SizedBox(height: 10),
                Text(
                  'No matching city',
                  textAlign: TextAlign.center,
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Try searching for another major Indian city.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool _isCurrent(String city) =>
      !widget.current.nearMe &&
      (widget.current.city ?? '').toLowerCase() == city.toLowerCase();
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.iconColor = AppColors.muted,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: selected ? AppColors.brand : iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? AppColors.brandText : AppColors.ink,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.brand)
          : null,
      onTap: onTap,
    );
  }
}
