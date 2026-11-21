import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import 'discovery_models.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

String _genderTag(GenderPreference gender) => switch (gender) {
      GenderPreference.male => 'MEN',
      GenderPreference.female => 'WOMEN',
      GenderPreference.coEd => 'CO-LIVING',
      GenderPreference.unspecified => 'UNSPECIFIED',
    };

/// Only the PG name and place sit below the image; stay type and price live
/// inside the poster to keep search results compact.
const double pgPosterTextHeight = 44;
const double pgPosterImageHeightRatio = .78;

class PgPosterCard extends StatelessWidget {
  final PgSearchResult pg;
  final VoidCallback onTap;
  final double? width;
  final double? distanceKm;

  const PgPosterCard({
    super.key,
    required this.pg,
    required this.onTap,
    this.width,
    this.distanceKm,
  });

  bool get _showMonthly => pg.offersMonthly != false;
  bool get _showDayWise => pg.offersDayWise == true;

  String get _semanticLabel {
    final details = <String>[
      pg.name,
      _place,
      _genderTag(pg.genderPreference).toLowerCase(),
      pg.verified ? 'verified property' : 'unverified listing',
    ];
    if (pg.verified && _showMonthly) {
      details.add(pg.minRentPerBed == null
          ? 'monthly price on request'
          : '${_money.format(pg.minRentPerBed)} per month');
    }
    if (pg.verified && _showDayWise) {
      details.add(pg.minDayWiseRate == null
          ? 'day-wise price on request'
          : '${_money.format(pg.minDayWiseRate)} per day');
    }
    if (pg.verified) {
      details.add(pg.availableBeds > 0
          ? '${pg.availableBeds} ${pg.availableBeds == 1 ? 'bed' : 'beds'} available'
          : 'no beds available now');
    }
    return details.join(', ');
  }

  String get _place {
    final distance = distanceKm;
    if (distance == null) return pg.city;
    final km = distance < 10
        ? distance.toStringAsFixed(1)
        : distance.toStringAsFixed(0);
    return '$km km · ${pg.city}';
  }

  @override
  Widget build(BuildContext context) {
    final free = pg.availableBeds;
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: _semanticLabel,
        hint: 'View property details',
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.medium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadii.medium,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      pg.photoUrl == null
                          ? _PosterPlaceholder(seed: pg.id)
                          : Image.network(
                              pg.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _PosterPlaceholder(seed: pg.id),
                            ),
                      const Positioned.fill(child: _PosterGradient()),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _Tag(
                          label: _genderTag(pg.genderPreference),
                          background: AppColors.ink.withValues(alpha: .86),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _VerificationTag(verified: pg.verified),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (pg.verified && _showMonthly)
                              _PriceLine(
                                label: 'MONTHLY',
                                amount: pg.minRentPerBed == null
                                    ? 'On request'
                                    : _money.format(pg.minRentPerBed),
                              ),
                            if (pg.verified && _showDayWise) ...[
                              const SizedBox(height: 3),
                              _PriceLine(
                                label: 'DAY-WISE',
                                amount: pg.minDayWiseRate == null
                                    ? 'On request'
                                    : _money.format(pg.minDayWiseRate),
                              ),
                            ],
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: free > 0
                                        ? AppColors.successBright
                                        : AppColors.subtle,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    !pg.verified
                                        ? 'View listing details'
                                        : free > 0
                                            ? '$free ${free == 1 ? 'bed' : 'beds'} free'
                                            : 'Full right now',
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                pg.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A horizontal, image-led card for accommodation search results.
/// Every label is derived from the public discovery response.
class PgHorizontalCard extends StatelessWidget {
  final PgSearchResult pg;
  final VoidCallback onTap;
  final double? distanceKm;

  const PgHorizontalCard({
    super.key,
    required this.pg,
    required this.onTap,
    this.distanceKm,
  });

  String get _place {
    final address = pg.address.trim();
    final location = address.isEmpty ? pg.city : '$address, ${pg.city}';
    final distance = distanceKm;
    if (distance == null) return location;
    final km = distance < 10
        ? distance.toStringAsFixed(1)
        : distance.toStringAsFixed(0);
    return '$km km away · $location';
  }

  String? get _monthlyPrice => pg.minRentPerBed == null
      ? null
      : '${_money.format(pg.minRentPerBed)}/month';

  String? get _dayWisePrice => pg.minDayWiseRate == null
      ? null
      : '${_money.format(pg.minDayWiseRate)}/day';

  String get _semanticLabel {
    final details = <String>[
      pg.name,
      _place,
      _genderTag(pg.genderPreference).toLowerCase(),
      pg.verified ? 'verified property' : 'unverified listing',
    ];
    if (pg.verified && _monthlyPrice != null) {
      details.add(_monthlyPrice!);
    } else if (pg.verified && _dayWisePrice != null) {
      details.add(_dayWisePrice!);
    }
    if (pg.verified) {
      details.add(pg.availableBeds > 0
          ? '${pg.availableBeds} ${pg.availableBeds == 1 ? 'bed' : 'beds'} available'
          : 'no beds available now');
    }
    return details.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cardHeight = 174 + ((textScale - 1).clamp(0, 2) * 128).toDouble();
    return Semantics(
      button: true,
      label: _semanticLabel,
      hint: 'View property details',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.medium,
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: cardHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final imageWidth = constraints.maxWidth < 360 ? 118.0 : 142.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: imageWidth,
                      child: Hero(
                        tag: 'pg-image-${pg.id}',
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            pg.photoUrl == null
                                ? _PosterPlaceholder(seed: pg.id)
                                : Image.network(
                                    pg.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _PosterPlaceholder(seed: pg.id),
                                  ),
                            Positioned(
                              top: 9,
                              left: 9,
                              child: _Tag(
                                label: _genderTag(pg.genderPreference),
                                background:
                                    AppColors.ink.withValues(alpha: .88),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    pg.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  pg.verified
                                      ? Icons.verified_rounded
                                      : Icons.shield_outlined,
                                  size: 17,
                                  color: pg.verified
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(Icons.location_on_outlined,
                                      size: 14, color: AppColors.muted),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _place,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            if (!pg.verified)
                              const Text(
                                'View listing details',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            else ...[
                              if (_monthlyPrice != null)
                                Text(
                                  _monthlyPrice!,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              else if (_dayWisePrice != null)
                                Text(
                                  _dayWisePrice!,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              if (_monthlyPrice != null &&
                                  _dayWisePrice != null)
                                Text(
                                  'Also ${_dayWisePrice!}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: pg.verified && pg.availableBeds > 0
                                        ? AppColors.successBright
                                        : AppColors.subtle,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    !pg.verified
                                        ? 'Verification pending'
                                        : pg.availableBeds > 0
                                            ? '${pg.availableBeds} ${pg.availableBeds == 1 ? 'bed' : 'beds'} available'
                                            : 'No beds available now',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: pg.verified &&
                                                  pg.availableBeds > 0
                                              ? AppColors.success
                                              : AppColors.muted,
                                          letterSpacing: 0,
                                        ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppColors.muted),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationTag extends StatelessWidget {
  final bool verified;

  const _VerificationTag({required this.verified});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: verified
            ? AppColors.success.withValues(alpha: .92)
            : const Color(0xFFF59E0B).withValues(alpha: .94),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.shield_outlined,
            color: Colors.white,
            size: 10,
          ),
          const SizedBox(width: 3),
          Text(
            verified ? 'VERIFIED' : 'UNVERIFIED',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterGradient extends StatelessWidget {
  const _PosterGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.transparent, Color(0xE6000000)],
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String label;
  final String amount;

  const _PriceLine({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(AppRadii.xs),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: .35,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color background;

  const _Tag({required this.label, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: .35,
        ),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  final String seed;

  const _PosterPlaceholder({required this.seed});

  static const _backgrounds = <Color>[
    AppColors.ink,
    AppColors.inkSoft,
    AppColors.brand,
    AppColors.brandPressed,
    Color(0xFF55586B),
    Color(0xFF747686),
  ];

  static const _icons = <IconData>[
    Icons.apartment_rounded,
    Icons.home_work_rounded,
    Icons.holiday_village_rounded,
    Icons.domain_rounded,
    Icons.location_city_rounded,
    Icons.bedroom_parent_rounded,
  ];

  int get _variant =>
      seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
      _backgrounds.length;

  @override
  Widget build(BuildContext context) {
    final background = _backgrounds[_variant];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -18,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -28,
            bottom: 20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .22),
                ),
              ),
              child: Icon(_icons[_variant], color: Colors.white, size: 35),
            ),
          ),
          Positioned(
            right: 9,
            bottom: 8,
            child: Text(
              'ILLUSTRATION',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .72),
                fontSize: 6.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PgPosterSkeleton extends StatelessWidget {
  final double? width;

  const PgPosterSkeleton({super.key, this.width});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w) => Container(
          width: w,
          height: 9,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
    return Semantics(
      label: 'Loading property',
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadii.medium,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              bar(100),
              const SizedBox(height: 5),
              bar(65),
            ],
          ),
        ),
      ),
    );
  }
}
