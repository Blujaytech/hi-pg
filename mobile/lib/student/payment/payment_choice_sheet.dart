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
        24,
        0,
        24,
        20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose how to pay',
            textAlign: TextAlign.center,
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          Text(
            propertyName == null
                ? 'Your bed is confirmed after payment verification.'
                : 'Complete payment for $propertyName. Your bed is confirmed after verification.',
            textAlign: TextAlign.center,
            style: Theme.of(sheetContext)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          _PaymentChoiceButton(
            title: 'Pay Online',
            subtitle: 'UPI, Card or Net Banking',
            primary: true,
            onTap: () =>
                Navigator.pop(sheetContext, BookingPaymentChoice.online),
          ),
          const SizedBox(height: 10),
          _PaymentChoiceButton(
            title: 'Pay Directly to Owner',
            subtitle: directOwnerAvailable
                ? "Use the owner's UPI and request verification"
                : 'Owner setup pending',
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
                    'The owner must enable Direct Payment from their property Payments screen after completing the required verification.',
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
          Text(
            directOwnerAvailable
                ? 'For direct payment, inform the owner after paying. The booking is confirmed only after the exact amount is verified.'
                : 'Direct payment appears after the owner enables it.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ],
      ),
    ),
  );
}

class _PaymentChoiceButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool primary;
  final bool available;
  final VoidCallback onTap;

  const _PaymentChoiceButton({
    required this.title,
    required this.subtitle,
    this.primary = false,
    this.available = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : AppColors.ink;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Material(
          color: primary
              ? AppColors.brand
              : available
                  ? AppColors.surface
                  : AppColors.fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: primary ? AppColors.brand : AppColors.border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: primary
                                ? Colors.white.withValues(alpha: .82)
                                : AppColors.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 19, color: foreground.withValues(alpha: .8)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
