import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/student/profile/customer_profile_models.dart';
import 'package:pg_platform_mobile/student/profile/customer_profile_repository.dart';
import 'package:pg_platform_mobile/student/profile/customer_profile_screen.dart';

class _ProfileRepository extends CustomerProfileRepository {
  final CustomerProfile profile;

  _ProfileRepository(this.profile);

  @override
  Future<CustomerProfile> getMine() async => profile;
}

void main() {
  const document = CustomerIdentityDocument(
    id: 'document-id',
    identityType: IdentityType.aadhaar,
    fileName: 'aadhaar.pdf',
    contentType: 'application/pdf',
    sizeBytes: 1024,
    uploadedAt: null,
  );
  final completeProfile = CustomerProfile(
    id: 'profile-id',
    fullName: 'Nazeer Basha Shaik',
    occupation: 'Software engineer',
    phone: '+919652297185',
    phoneVerified: false,
    permanentAddress: 'Vijayawada, Andhra Pradesh',
    identityType: IdentityType.aadhaar,
    identityLast4: null,
    identityDocument: document,
    termsAcceptedVersion: 'v1',
    privacyAcceptedVersion: 'v1',
    aadhaarConsentVersion: 'v1',
    updatedAt: DateTime(2026, 9, 27),
  );

  testWidgets('a saved profile opens as a summary and remains editable',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerProfileScreen(
          repository: _ProfileRepository(completeProfile),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile complete'), findsOneWidget);
    expect(find.text('Document submitted'), findsOneWidget);
    expect(find.text('Save profile'), findsNothing);

    final editButton = find.widgetWithText(TextButton, 'Edit');
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Full legal name'), findsOneWidget);
  });
}
