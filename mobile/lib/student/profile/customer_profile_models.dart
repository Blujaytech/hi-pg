import '../booking/booking_models.dart';

enum IdentityType { aadhaar, passport, drivingLicence, voterId, other }

extension IdentityTypeX on IdentityType {
  String get apiValue => switch (this) {
        IdentityType.aadhaar => 'AADHAAR',
        IdentityType.passport => 'PASSPORT',
        IdentityType.drivingLicence => 'DRIVING_LICENCE',
        IdentityType.voterId => 'VOTER_ID',
        IdentityType.other => 'OTHER',
      };

  String get label => switch (this) {
        IdentityType.aadhaar => 'Aadhaar',
        IdentityType.passport => 'Passport',
        IdentityType.drivingLicence => 'Driving licence',
        IdentityType.voterId => 'Voter ID',
        IdentityType.other => 'Other government ID',
      };

  static IdentityType? fromApi(String? value) => switch (value) {
        'AADHAAR' => IdentityType.aadhaar,
        'PASSPORT' => IdentityType.passport,
        'DRIVING_LICENCE' => IdentityType.drivingLicence,
        'VOTER_ID' => IdentityType.voterId,
        'OTHER' => IdentityType.other,
        _ => null,
      };
}

class CustomerProfile {
  final String? id;
  final String fullName;
  final String occupation;
  final String? phone;
  final bool phoneVerified;
  final String? permanentAddress;
  final IdentityType? identityType;
  final String? identityLast4;
  final String? termsAcceptedVersion;
  final String? privacyAcceptedVersion;
  final String? aadhaarConsentVersion;
  final DateTime? updatedAt;

  const CustomerProfile({
    required this.id,
    required this.fullName,
    required this.occupation,
    required this.phone,
    required this.phoneVerified,
    required this.permanentAddress,
    required this.identityType,
    required this.identityLast4,
    required this.termsAcceptedVersion,
    required this.privacyAcceptedVersion,
    required this.aadhaarConsentVersion,
    required this.updatedAt,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) =>
      CustomerProfile(
        id: json['id'] as String?,
        fullName: json['fullName'] as String? ?? '',
        occupation: json['occupation'] as String? ?? '',
        phone: json['phone'] as String?,
        phoneVerified: json['phoneVerified'] as bool? ?? false,
        permanentAddress: json['permanentAddress'] as String?,
        identityType: IdentityTypeX.fromApi(json['identityType'] as String?),
        identityLast4: json['identityLast4'] as String?,
        termsAcceptedVersion: json['termsAcceptedVersion'] as String?,
        privacyAcceptedVersion: json['privacyAcceptedVersion'] as String?,
        aadhaarConsentVersion: json['aadhaarConsentVersion'] as String?,
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
      );
}

enum ProfileRequirement {
  profile,
  fullName,
  occupation,
  verifiedMobile,
  termsAcceptance,
  privacyAcceptance,
  permanentAddress,
  identity,
  aadhaarConsent,
  unknown,
}

extension ProfileRequirementX on ProfileRequirement {
  static ProfileRequirement fromApi(String value) => switch (value) {
        'PROFILE' => ProfileRequirement.profile,
        'FULL_NAME' => ProfileRequirement.fullName,
        'OCCUPATION' => ProfileRequirement.occupation,
        'VERIFIED_MOBILE' => ProfileRequirement.verifiedMobile,
        'TERMS_ACCEPTANCE' => ProfileRequirement.termsAcceptance,
        'PRIVACY_ACCEPTANCE' => ProfileRequirement.privacyAcceptance,
        'PERMANENT_ADDRESS' => ProfileRequirement.permanentAddress,
        'IDENTITY' => ProfileRequirement.identity,
        'AADHAAR_CONSENT' => ProfileRequirement.aadhaarConsent,
        _ => ProfileRequirement.unknown,
      };

  String get label => switch (this) {
        ProfileRequirement.profile => 'Create your customer profile',
        ProfileRequirement.fullName => 'Add your full legal name',
        ProfileRequirement.occupation => 'Add your occupation',
        ProfileRequirement.verifiedMobile => 'Verify your mobile number',
        ProfileRequirement.termsAcceptance => 'Accept the Terms of Service',
        ProfileRequirement.privacyAcceptance => 'Accept the Privacy Policy',
        ProfileRequirement.permanentAddress => 'Add your permanent address',
        ProfileRequirement.identity =>
          'Add a government ID type and its last 4 characters',
        ProfileRequirement.aadhaarConsent =>
          'Give specific consent to use Aadhaar details',
        ProfileRequirement.unknown => 'Complete the required profile details',
      };
}

class BookingEligibility {
  final BookingType bookingType;
  final bool eligible;
  final List<ProfileRequirement> missingRequirements;

  const BookingEligibility({
    required this.bookingType,
    required this.eligible,
    required this.missingRequirements,
  });

  factory BookingEligibility.fromJson(Map<String, dynamic> json) =>
      BookingEligibility(
        bookingType:
            BookingTypeX.fromApi(json['bookingType'] as String? ?? 'DAY_WISE'),
        eligible: json['eligible'] as bool? ?? false,
        missingRequirements:
            (json['missingRequirements'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .map(ProfileRequirementX.fromApi)
                .toList(),
      );
}

extension CustomerProfileEligibility on CustomerProfile {
  /// Mirrors the server's booking gate so a customer can still reach the
  /// mandatory profile form during a rolling deployment where an older API
  /// rejects the newer eligibility query contract. The booking endpoint
  /// remains authoritative and checks the same requirements server-side.
  BookingEligibility eligibilityFor(BookingType bookingType) {
    final missing = <ProfileRequirement>[];
    if (id == null) missing.add(ProfileRequirement.profile);
    if (fullName.trim().isEmpty || fullName.trim().toLowerCase() == 'student') {
      missing.add(ProfileRequirement.fullName);
    }
    if (occupation.trim().isEmpty) {
      missing.add(ProfileRequirement.occupation);
    }
    if (termsAcceptedVersion == null) {
      missing.add(ProfileRequirement.termsAcceptance);
    }
    if (privacyAcceptedVersion == null) {
      missing.add(ProfileRequirement.privacyAcceptance);
    }
    if (bookingType == BookingType.monthly) {
      if (permanentAddress?.trim().isEmpty ?? true) {
        missing.add(ProfileRequirement.permanentAddress);
      }
      final hasIdentity = identityType != null &&
          RegExp(r'^[A-Za-z0-9]{4}$').hasMatch(identityLast4?.trim() ?? '');
      if (!hasIdentity) {
        missing.add(ProfileRequirement.identity);
      } else if (identityType == IdentityType.aadhaar &&
          aadhaarConsentVersion == null) {
        missing.add(ProfileRequirement.aadhaarConsent);
      }
    }
    return BookingEligibility(
      bookingType: bookingType,
      eligible: missing.isEmpty,
      missingRequirements: List.unmodifiable(missing),
    );
  }
}
