import 'package:flutter/material.dart';

import '../../core/theme.dart';

enum BookingPaymentChoice { online, directOwner }

Future<BookingPaymentChoice?> showBookingPaymentChoice(
  BuildContext context, {
  String? propertyName,
  bool directOwnerAvailable = true,
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
            subtitle: directOwnerAvailable
                ? "View the owner's UPI and mobile, then request verification"
                : 'This PG owner has not enabled direct payment yet',
            availabilityLabel:
                directOwnerAvailable ? null : 'Owner setup pending',
            available: directOwnerAvailable,
            onTap: () {
              if (directOwnerAvailable) {
                Navigator.pop(sheetContext, BookingPaymentChoice.directOwner);
                return;
              }
              showDialog<void>(
                context: sheetContext,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Direct payment is not enabled'),
                  content: const Text(
                    'The owner must enable Direct Payment from their property Payments screen after completing the required verification. Once enabled, you will see the owner payment details and can send a verification request.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 17, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  directOwnerAvailable
                      ? 'After you pay, tap “I Have Paid – Inform Owner.” The bed is confirmed only after the owner verifies the exact amount and approves it.'
                      : 'Direct payment details are private and appear only after the owner enables this method and you create a booking hold.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
  final bool available;
  final String? availabilityLabel;
  final VoidCallback onTap;

  const _PaymentChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.recommended = false,
    this.available = true,
    this.availabilityLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: recommended
          ? AppColors.ink
          : available
              ? AppColors.surface
              : AppColors.fill,
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
                        if (availabilityLabel != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                availabilityLabel!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
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
