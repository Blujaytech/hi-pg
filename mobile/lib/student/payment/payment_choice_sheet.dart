import 'package:flutter/material.dart';

import '../../core/theme.dart';

enum BookingPaymentChoice { online, directOwner }

Future<BookingPaymentChoice?> showBookingPaymentChoice(
  BuildContext context, {
  String? propertyName,
}) {
  return showModalBottomSheet<BookingPaymentChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choose how to pay',
              style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            propertyName == null
                ? 'Your bed is confirmed only after the payment is verified.'
                : 'Complete payment for $propertyName. Your bed is confirmed only after verification.',
            style: Theme.of(sheetContext)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          _PaymentChoiceCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Pay Online',
            subtitle: 'Pay securely using UPI, Card, or Net Banking',
            recommended: true,
            onTap: () =>
                Navigator.pop(sheetContext, BookingPaymentChoice.online),
          ),
          const SizedBox(height: 12),
          _PaymentChoiceCard(
            icon: Icons.person_pin_circle_outlined,
            title: 'Pay Directly to Owner',
            subtitle: "Pay to the PG owner's configured UPI ID and notify them",
            onTap: () =>
                Navigator.pop(sheetContext, BookingPaymentChoice.directOwner),
          ),
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 17, color: AppColors.muted),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Direct UPI payments are verified by the owner. Marking a payment as sent does not allocate the bed.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PaymentChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool recommended;
  final VoidCallback onTap;

  const _PaymentChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.recommended = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: recommended ? AppColors.ink : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: recommended ? AppColors.ink : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: recommended
                      ? Colors.white.withValues(alpha: .13)
                      : AppColors.fill,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon,
                    color: recommended ? Colors.white : AppColors.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: recommended
                                      ? Colors.white
                                      : AppColors.ink,
                                ),
                          ),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Recommended',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: recommended
                                ? Colors.white.withValues(alpha: .7)
                                : AppColors.muted,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: recommended ? Colors.white : AppColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}
