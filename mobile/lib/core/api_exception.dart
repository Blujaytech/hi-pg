/// Mirrors the backend's ApiError shape (com.pgplatform.common.ApiError) so
/// every screen can show a real message instead of a generic "Something
/// went wrong".
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final List<String> details;

  ApiException({required this.message, this.statusCode, this.details = const []});

  @override
  String toString() => message;
}
