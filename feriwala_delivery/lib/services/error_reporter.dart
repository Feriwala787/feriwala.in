import 'package:flutter/foundation.dart';

class ErrorReporter {
  static final _sensitivePatterns = <RegExp>[
    RegExp(r'Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*', caseSensitive: false),
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    RegExp(r'\b\d{10,13}\b'),
  ];

  static String sanitize(String input) {
    var redacted = input;
    for (final pattern in _sensitivePatterns) {
      redacted = redacted.replaceAll(pattern, '[REDACTED]');
    }
    return redacted;
  }

  static void report(Object error, StackTrace stackTrace, {String? context}) {
    debugPrint('[delivery] ${context ?? 'error'}: ${sanitize(error.toString())}');
    debugPrintStack(stackTrace: stackTrace);
  }

  static void message(String message) {
    debugPrint('[delivery] ${sanitize(message)}');
  }
}
