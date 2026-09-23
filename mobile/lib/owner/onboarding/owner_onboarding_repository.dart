import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

import '../../core/api_exception.dart';
import '../../shared/api_client.dart';
import 'owner_kyc_models.dart';

class OwnerOnboardingRepository {
  final ApiClient _client = ApiClient.instance;

  Future<OwnerKycSubmission?> getKyc(String pgId) async {
    try {
      final response =
          await _client.get<Map<String, dynamic>>('/owner/pgs/$pgId/kyc');
      return OwnerKycSubmission.fromJson(response.data!);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> requestPhoneOtp(String phone) async {
    await _client
        .post<void>('/owner/profile/phone/otp/request', data: {'phone': phone});
  }

  Future<void> verifyPhoneOtp(String phone, String code) async {
    await _client.post<void>('/owner/profile/phone/otp/verify',
        data: {'phone': phone, 'code': code});
  }

  Future<OwnerKycSubmission> saveProfile({
    required String pgId,
    required String legalName,
    required String panLastFour,
    required String aadhaarLastFour,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/owner/pgs/$pgId/kyc',
      data: {
        'legalName': legalName.trim(),
        'panLastFour': panLastFour.trim().toUpperCase(),
        'aadhaarLastFour': aadhaarLastFour.trim(),
      },
    );
    return OwnerKycSubmission.fromJson(response.data!);
  }

  Future<OwnerKycSubmission> uploadDocument({
    required String pgId,
    required OwnerKycDocumentType type,
    required PlatformFile file,
  }) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw ApiException(message: 'The selected file could not be read.');
    }
    final contentType = _contentType(file.extension);
    final response = await _client.post<Map<String, dynamic>>(
      '/owner/pgs/$pgId/kyc/documents',
      data: FormData.fromMap({
        'documentType': type.apiValue,
        'file': MultipartFile.fromBytes(
          bytes,
          filename: file.name,
          contentType: MediaType.parse(contentType),
        ),
      }),
    );
    return OwnerKycSubmission.fromJson(response.data!);
  }

  Future<OwnerKycSubmission> submit(String pgId) async {
    final response =
        await _client.post<Map<String, dynamic>>('/owner/pgs/$pgId/kyc/submit');
    return OwnerKycSubmission.fromJson(response.data!);
  }

  String _contentType(String? extension) => switch (extension?.toLowerCase()) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        _ => 'image/jpeg',
      };
}
