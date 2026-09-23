import '../../shared/api_client.dart';
import '../booking/booking_models.dart';
import 'customer_profile_models.dart';

class CustomerProfileRepository {
  final ApiClient _client = ApiClient.instance;

  Future<CustomerProfile> getMine() async {
    final response =
        await _client.get<Map<String, dynamic>>('/student/profile');
    return CustomerProfile.fromJson(response.data!);
  }

  Future<CustomerProfile> save({
    required String fullName,
    required String occupation,
    String? permanentAddress,
    IdentityType? identityType,
    String? identityLast4,
    required bool acceptTerms,
    required bool acceptPrivacy,
    required bool acceptAadhaarConsent,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/student/profile',
      data: {
        'fullName': fullName.trim(),
        'occupation': occupation.trim(),
        'permanentAddress': _blankToNull(permanentAddress),
        'identityType': identityType?.apiValue,
        'identityLast4': _blankToNull(identityLast4)?.toUpperCase(),
        'acceptTerms': acceptTerms,
        'acceptPrivacy': acceptPrivacy,
        'acceptAadhaarConsent': acceptAadhaarConsent,
      },
    );
    return CustomerProfile.fromJson(response.data!);
  }

  Future<BookingEligibility> eligibility(BookingType bookingType) async {
    // The profile response already contains every field used by the booking
    // gate. Keeping eligibility client-side here avoids a second, redundant
    // request whose query binding differed across deployed API versions and
    // could stop a bed tap with the generic "Request validation failed"
    // response. Booking creation remains the authoritative server-side gate.
    final profile = await getMine();
    return profile.eligibilityFor(bookingType);
  }

  Future<void> requestPhoneOtp(String phone) => _client.post<void>(
        '/student/profile/phone/otp/request',
        data: {'phone': phone.trim()},
      );

  Future<CustomerProfile> verifyPhoneOtp(String phone, String code) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/student/profile/phone/otp/verify',
      data: {'phone': phone.trim(), 'code': code.trim()},
    );
    return CustomerProfile.fromJson(response.data!);
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
