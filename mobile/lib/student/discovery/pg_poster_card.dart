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
    };

/// Only the PG name and place sit below the image; stay type and price live
/// inside the poster to keep search results compact.
const double pgPosterTextHeight = 44;
const double pgPosterImageHeightRatio = 1.05;

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
        label: '${pg.name}, ${pg.city}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      pg.photoUrl == null
                          ? const _PosterPlaceholder()
                          : Image.network(
                              pg.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _PosterPlaceholder(),
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
                        left: 8,
                        right: 8,
                        bottom: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_showMonthly)
                              _PriceLine(
                                label: 'MONTHLY',
                                amount: pg.minRentPerBed == null
                                    ? 'On request'
                                    : _money.format(pg.minRentPerBed),
                              ),
                            if (_showDayWise) ...[
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
                                    free > 0
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
            borderRadius: BorderRadius.circular(4),
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
        borderRadius: BorderRadius.circular(4),
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
  const _PosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.inkSoft,
      child: Center(
        child: Icon(Icons.apartment_rounded, color: Colors.white54, size: 32),
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
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          bar(100),
          const SizedBox(height: 5),
          bar(65),
        ],
      ),
    );
  }
}
