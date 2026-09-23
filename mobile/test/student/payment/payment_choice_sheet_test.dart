import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/student/payment/payment_choice_sheet.dart';

void main() {
  testWidgets('keeps direct owner payment visible when setup is pending',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _PaymentSheetHost(false)));

    await tester.tap(find.text('Open payment choices'));
    await tester.pumpAndSettle();

    expect(find.text('Pay Online'), findsOneWidget);
    expect(find.text('Pay Directly to Owner'), findsOneWidget);
    expect(find.text('Owner setup pending'), findsOneWidget);

    await tester.tap(find.text('Pay Directly to Owner'));
    await tester.pumpAndSettle();

    expect(find.text('Direct payment is not enabled'), findsOneWidget);
    expect(
      find.textContaining('enable Direct Payment from their property Payments'),
      findsOneWidget,
    );
  });

  testWidgets('returns direct owner choice when the method is enabled',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _PaymentSheetHost(true)));

    await tester.tap(find.text('Open payment choices'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay Directly to Owner'));
    await tester.pumpAndSettle();

    expect(find.text('Selected: directOwner'), findsOneWidget);
  });
}

class _PaymentSheetHost extends StatefulWidget {
  final bool directOwnerAvailable;

  const _PaymentSheetHost(this.directOwnerAvailable);

  @override
  State<_PaymentSheetHost> createState() => _PaymentSheetHostState();
}

class _PaymentSheetHostState extends State<_PaymentSheetHost> {
  BookingPaymentChoice? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              final selected = await showBookingPaymentChoice(
                context,
                directOwnerAvailable: widget.directOwnerAvailable,
              );
              if (mounted) setState(() => _selected = selected);
            },
            child: const Text('Open payment choices'),
          ),
          Text('Selected: ${_selected?.name ?? 'none'}'),
        ],
      ),
    );
  }
}
