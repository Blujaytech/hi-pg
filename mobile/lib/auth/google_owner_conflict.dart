import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';

enum OwnerGmailChoice { anotherGoogleAccount, mobileNumber }

/// The server refuses customer Google sign-in for an email that already
/// belongs to a PG owner (ADR-0026, HTTP 409). Owners keep using owner login.
bool isOwnerGmailConflict(Object error) =>
    error is ApiException &&
    error.statusCode == 409 &&
    error.message.toLowerCase().contains('pg owner');

/// Explains why the chosen Gmail can't be used for a customer account and
/// offers the two ways forward.
Future<OwnerGmailChoice?> showOwnerGmailConflict(BuildContext context) {
  return showModalBottomSheet<OwnerGmailChoice>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.admin_panel_settings_outlined,
                    color: AppColors.warning),
              ),
            ),
            const SizedBox(height: 16),
            Text('This Gmail is a PG owner account',
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              "PG owners can't book beds with their owner Gmail. Choose a different Google account, or continue with your mobile number.",
              style: Theme.of(sheetContext)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                  sheetContext, OwnerGmailChoice.anotherGoogleAccount),
              icon: const Icon(Icons.switch_account_rounded, size: 19),
              label: const Text('Use another Google account'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pop(sheetContext, OwnerGmailChoice.mobileNumber),
              icon: const Icon(Icons.phone_iphone_rounded, size: 19),
              label: const Text('Continue with mobile number'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}
