import '../booking/booking_models.dart';

enum IdentityType { aadhaar, passport }

extension IdentityTypeX on IdentityType {
  String get apiValue => switch (this) {
        IdentityType.aadhaar => 'AADHAAR',
        IdentityType.passport => 'PASSPORT',
      };

  String get label => switch (this) {
        IdentityType.aadhaar => 'Aadhaar card',
        IdentityType.passport => 'Passport',
      };

  static IdentityType? fromApi(String? value) => switch (value) {
        'AADHAAR' => IdentityType.aadhaar,
        'PASSPORT' => IdentityType.passport,
        _ => null,
      };
}

class CustomerIdentityDocument {
  final String id;
  final IdentityType identityType;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final DateTime? uploadedAt;

  const CustomerIdentityDocument({
    required this.id,
    required this.identityType,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  factory CustomerIdentityDocument.fromJson(Map<String, dynamic> json) =>
      CustomerIdentityDocument(
        id: json['id'] as String,
        identityType: IdentityTypeX.fromApi(json['identityType'] as String?)!,
        fileName: json['fileName'] as String? ?? 'Identity document',
        contentType: json['contentType'] as String? ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        uploadedAt: json['uploadedAt'] == null
            ? null
            : DateTime.tryParse(json['uploadedAt'] as String),
      );
}

class CustomerProfile {
  final String? id;
  final String fullName;
  final String occupation;
  final String? profilePhotoUrl;
  final String? phone;
  final bool phoneVerified;
  final String? permanentAddress;
  final String? guardianName;
  final String? guardianPhone;
  final IdentityType? identityType;
  final String? identityLast4;
  final CustomerIdentityDocument? identityDocument;
  final String? termsAcceptedVersion;
  final String? privacyAcceptedVersion;
  final String? aadhaarConsentVersion;
  final DateTime? updatedAt;

  const CustomerProfile({
    required this.id,
    required this.fullName,
    required this.occupation,
    this.profilePhotoUrl,
    required this.phone,
    required this.phoneVerified,
    required this.permanentAddress,
    this.guardianName,
    this.guardianPhone,
    required this.identityType,
    required this.identityLast4,
    this.identityDocument,
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
        profilePhotoUrl: json['profilePhotoUrl'] as String?,
        phone: json['phone'] as String?,
        phoneVerified: json['phoneVerified'] as bool? ?? false,
        permanentAddress: json['permanentAddress'] as String?,
        guardianName: json['guardianName'] as String?,
        guardianPhone: json['guardianPhone'] as String?,
        identityType: IdentityTypeX.fromApi(json['identityType'] as String?),
        identityLast4: json['identityLast4'] as String?,
        identityDocument: json['identityDocument'] is Map<String, dynamic>
            ? CustomerIdentityDocument.fromJson(
                json['identityDocument'] as Map<String, dynamic>)
            : null,
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
  contactPhone,
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
        'CONTACT_PHONE' => ProfileRequirement.contactPhone,
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
        ProfileRequirement.contactPhone => 'Add a valid contact mobile number',
        ProfileRequirement.verifiedMobile => 'Verify your mobile number',
        ProfileRequirement.termsAcceptance => 'Accept the Terms of Service',
        ProfileRequirement.privacyAcceptance => 'Accept the Privacy Policy',
        ProfileRequirement.permanentAddress => 'Add your permanent address',
        ProfileRequirement.identity =>
          'Upload an Aadhaar card or passport document',
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
  bool get hasBasicProfile =>
      id != null &&
      fullName.trim().isNotEmpty &&
      fullName.trim().toLowerCase() != 'student' &&
      occupation.trim().isNotEmpty &&
      (phone?.trim().isNotEmpty ?? false) &&
      termsAcceptedVersion != null &&
      privacyAcceptedVersion != null;

  bool get hasMonthlyProfile =>
      hasBasicProfile &&
      (permanentAddress?.trim().isNotEmpty ?? false) &&
      identityType != null &&
      identityDocument?.identityType == identityType &&
      (identityType != IdentityType.aadhaar || aadhaarConsentVersion != null);

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
    if (phone?.trim().isEmpty ?? true) {
      missing.add(ProfileRequirement.contactPhone);
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
          identityDocument?.identityType == identityType;
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
