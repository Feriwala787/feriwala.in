import 'package:flutter_test/flutter_test.dart';
import 'package:feriwala_delivery/services/error_reporter.dart';

void main() {
  test('sanitize redacts bearer tokens, emails, and phone-like numbers', () {
    const raw = 'Authorization: Bearer abc123token, email test@example.com, phone 9876543210';
    final sanitized = ErrorReporter.sanitize(raw);

    expect(sanitized, isNot(contains('abc123token')));
    expect(sanitized, isNot(contains('test@example.com')));
    expect(sanitized, isNot(contains('9876543210')));
    expect('[REDACTED]'.allMatches(sanitized).length, greaterThanOrEqualTo(3));
  });
}
