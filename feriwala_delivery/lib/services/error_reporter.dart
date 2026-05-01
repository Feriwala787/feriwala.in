import 'package:flutter/foundation.dart';

class ErrorReporter {
  static void report(Object error, StackTrace stackTrace, {String? context}) {
    debugPrint('[delivery] ${context ?? 'error'}: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  static void message(String message) {
    debugPrint('[delivery] $message');
  }
}
