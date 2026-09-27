import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

import '../../core/api_exception.dart';
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
    required String contactPhone,
    String? permanentAddress,
    IdentityType? identityType,
    required bool acceptTerms,
    required bool acceptPrivacy,
    required bool acceptAadhaarConsent,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/student/profile',
      data: {
        'fullName': fullName.trim(),
        'occupation': occupation.trim(),
        'contactPhone': contactPhone.trim(),
        'permanentAddress': _blankToNull(permanentAddress),
        'identityType': identityType?.apiValue,
        'identityLast4': null,
        'acceptTerms': acceptTerms,
        'acceptPrivacy': acceptPrivacy,
        'acceptAadhaarConsent': acceptAadhaarConsent,
      },
    );
    return CustomerProfile.fromJson(response.data!);
  }

  Future<CustomerProfile> uploadIdentityDocument({
    required IdentityType identityType,
    required PlatformFile file,
  }) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw ApiException(message: 'The selected file could not be read.');
    }
    final response = await _client.post<Map<String, dynamic>>(
      '/student/profile/identity-document?identityType=${identityType.apiValue}',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: file.name,
          contentType: MediaType.parse(_contentType(file.extension)),
        ),
      }),
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

  String _contentType(String? extension) => switch (extension?.toLowerCase()) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        _ => 'image/jpeg',
      };

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
