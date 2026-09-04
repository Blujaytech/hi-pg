enum UserRole { owner, student }

UserRole roleFromString(String value) => value.toUpperCase() == 'OWNER' ? UserRole.owner : UserRole.student;

class AuthSession {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String fullName;
  final UserRole role;

  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.fullName,
    required this.role,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      role: roleFromString(json['role'] as String),
    );
  }
}
