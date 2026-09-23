enum UserRole {
  owner('OWNER'),
  student('STUDENT'),
  admin('ADMIN');

  const UserRole(this.apiValue);
  final String apiValue;
}

UserRole roleFromString(String value) => switch (value.toUpperCase()) {
      'OWNER' => UserRole.owner,
      'ADMIN' => UserRole.admin,
      _ => UserRole.student,
    };

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
