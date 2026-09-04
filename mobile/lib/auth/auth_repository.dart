import '../shared/api_client.dart';
import 'auth_models.dart';

/// Every call the app makes to /api/v1/auth/**. Screens/state should go
/// through this, never call ApiClient directly for auth -- keeps the auth
/// contract in one place if the backend endpoints shift.
class AuthRepository {
  final ApiClient _client = ApiClient.instance;

  Future<AuthSession> ownerSignup({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await _client.post<Map<String, dynamic>>('/auth/owner/signup', data: {
      'fullName': fullName,
      'email': email,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    return AuthSession.fromJson(response.data!);
  }

  Future<AuthSession> ownerLogin({required String email, required String password}) async {
    final response = await _client.post<Map<String, dynamic>>('/auth/owner/login', data: {
      'email': email,
      'password': password,
    });
    return AuthSession.fromJson(response.data!);
  }

  Future<void> requestStudentOtp({required String phone}) async {
    await _client.post<void>('/auth/student/otp/request', data: {'phone': phone});
  }

  Future<AuthSession> verifyStudentOtp({required String phone, required String code, String? fullName}) async {
    final response = await _client.post<Map<String, dynamic>>('/auth/student/otp/verify', data: {
      'phone': phone,
      'code': code,
      if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
    });
    return AuthSession.fromJson(response.data!);
  }

  Future<void> requestPasswordReset({required String email}) async {
    await _client.post<void>('/auth/owner/password-reset/request', data: {'email': email});
  }

  Future<void> logout({required String refreshToken}) async {
    await _client.post<void>('/auth/logout', data: {'refreshToken': refreshToken});
  }
}
