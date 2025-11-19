import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// Centralized logging framework for FamQuest
/// Replaces all print() statements with proper logging
///
/// Features:
/// - Log levels: debug, info, warning, error, fatal
/// - Production filtering (only warnings+ in release mode)
/// - PII masking for sensitive data
/// - Structured logging with timestamps
class AppLogger {
  static final Logger _logger = Logger(
    filter: ProductionFilter(),
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Debug level - detailed information for debugging
  /// Only shown in debug mode
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.d(_maskSensitiveData(message), error: error, stackTrace: stackTrace);
    }
  }

  /// Info level - general informational messages
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(_maskSensitiveData(message), error: error, stackTrace: stackTrace);
  }

  /// Warning level - potentially harmful situations
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(_maskSensitiveData(message), error: error, stackTrace: stackTrace);
  }

  /// Error level - error events that might still allow the app to continue
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(_maskSensitiveData(message), error: error, stackTrace: stackTrace);
  }

  /// Fatal level - very severe error events that will lead the app to abort
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(_maskSensitiveData(message), error: error, stackTrace: stackTrace);
  }

  /// Mask sensitive data in log messages (GDPR/COPPA compliance)
  ///
  /// Masks:
  /// - Email addresses → [EMAIL_REDACTED]
  /// - Bearer tokens → Bearer [TOKEN_REDACTED]
  /// - UUIDs → [UUID_REDACTED]
  /// - Passwords → [PASSWORD_REDACTED]
  static String _maskSensitiveData(String message) {
    String masked = message;

    // Mask email addresses
    masked = masked.replaceAll(
      RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w+\b'),
      '[EMAIL_REDACTED]',
    );

    // Mask Bearer tokens
    masked = masked.replaceAll(
      RegExp(r'Bearer\s+[\w\.-]+'),
      'Bearer [TOKEN_REDACTED]',
    );

    // Mask UUIDs
    masked = masked.replaceAll(
      RegExp(
        r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
        caseSensitive: false,
      ),
      '[UUID_REDACTED]',
    );

    // Mask password keywords
    masked = masked.replaceAll(
      RegExp(r'password["\s:=]+[^\s,"]+', caseSensitive: false),
      'password: [PASSWORD_REDACTED]',
    );

    return masked;
  }
}
