import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/student/booking/booking_models.dart';
import 'package:pg_platform_mobile/student/profile/customer_profile_models.dart';

void main() {
  CustomerProfile profile({
    String? id = 'profile-id',
    String fullName = 'Google Customer',
    String occupation = 'Engineer',
    String? phone = '+919000000001',
    bool phoneVerified = true,
    String? permanentAddress,
    IdentityType? identityType,
    CustomerIdentityDocument? identityDocument,
    String? termsAcceptedVersion = 'v1',
    String? privacyAcceptedVersion = 'v1',
    String? aadhaarConsentVersion,
  }) =>
      CustomerProfile(
        id: id,
        fullName: fullName,
        occupation: occupation,
        phone: phone,
        phoneVerified: phoneVerified,
        permanentAddress: permanentAddress,
        identityType: identityType,
        identityLast4: null,
        identityDocument: identityDocument,
        termsAcceptedVersion: termsAcceptedVersion,
        privacyAcceptedVersion: privacyAcceptedVersion,
        aadhaarConsentVersion: aadhaarConsentVersion,
        updatedAt: null,
      );

  test('a new Google customer is sent to every mandatory monthly field', () {
    final eligibility = profile(
      id: null,
      occupation: '',
      phone: null,
      phoneVerified: false,
      termsAcceptedVersion: null,
      privacyAcceptedVersion: null,
    ).eligibilityFor(BookingType.monthly);

    expect(eligibility.eligible, isFalse);
    expect(
      eligibility.missingRequirements,
      containsAll(<ProfileRequirement>[
        ProfileRequirement.profile,
        ProfileRequirement.occupation,
        ProfileRequirement.termsAcceptance,
        ProfileRequirement.privacyAcceptance,
        ProfileRequirement.permanentAddress,
        ProfileRequirement.identity,
      ]),
    );
  });

  test('day-wise booking does not require a verified mobile', () {
    final eligibility = profile(
      phone: '+919000000002',
      phoneVerified: false,
    ).eligibilityFor(BookingType.dayWise);

    expect(eligibility.eligible, isTrue);
  });

  test('complete day-wise profile does not require monthly identity fields',
      () {
    final complete = profile();

    expect(complete.hasBasicProfile, isTrue);
    expect(complete.hasMonthlyProfile, isFalse);
    expect(complete.eligibilityFor(BookingType.dayWise).eligible, isTrue);
  });

  test('monthly profile is complete only with address and submitted identity',
      () {
    final complete = profile(
      permanentAddress: '1 Test Road, Hyderabad',
      identityType: IdentityType.passport,
      identityDocument: const CustomerIdentityDocument(
        id: 'document-id',
        identityType: IdentityType.passport,
        fileName: 'passport.pdf',
        contentType: 'application/pdf',
        sizeBytes: 100,
        uploadedAt: null,
      ),
    );

    expect(complete.hasBasicProfile, isTrue);
    expect(complete.hasMonthlyProfile, isTrue);
  });

  test('monthly Aadhaar selection requires its separate consent', () {
    final eligibility = profile(
      permanentAddress: '1 Test Road',
      identityType: IdentityType.aadhaar,
      identityDocument: const CustomerIdentityDocument(
        id: 'document-id',
        identityType: IdentityType.aadhaar,
        fileName: 'aadhaar.pdf',
        contentType: 'application/pdf',
        sizeBytes: 100,
        uploadedAt: null,
      ),
    ).eligibilityFor(BookingType.monthly);

    expect(
      eligibility.missingRequirements,
      equals(<ProfileRequirement>[ProfileRequirement.aadhaarConsent]),
    );
  });
}
