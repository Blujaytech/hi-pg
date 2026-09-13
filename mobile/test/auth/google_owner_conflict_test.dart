import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/auth/google_owner_conflict.dart';
import 'package:pg_platform_mobile/core/api_exception.dart';

void main() {
  test('the server refusing an owner Gmail is recognised', () {
    // Both messages GoogleAuthService sends for an owner's Google identity.
    expect(
        isOwnerGmailConflict(ApiException(
            message:
                'This Google email belongs to a PG owner. Use owner login instead.',
            statusCode: 409)),
        isTrue);
    expect(
        isOwnerGmailConflict(ApiException(
            message:
                'This Google account belongs to a PG owner. Use owner login instead.',
            statusCode: 409)),
        isTrue);
  });

  test('other failures are not mistaken for the owner case', () {
    expect(
        isOwnerGmailConflict(ApiException(
            message: 'This email is already linked to another Google account.',
            statusCode: 409)),
        isFalse);
    expect(
        isOwnerGmailConflict(
            ApiException(message: 'Invalid credentials', statusCode: 401)),
        isFalse);
    expect(isOwnerGmailConflict(Exception('network')), isFalse);
  });
}
