import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_logger.dart';

/// Validates that all required secrets are configured
/// Part of bank-grade security implementation
///
/// Validates on app startup:
/// - Supabase credentials (URL, anon key)
/// - API endpoints
/// - Environment configuration
///
/// Throws exception if secrets are missing, preventing app start with invalid config
class SecretsValidator {
  /// Validate all required secrets are present
  static Future<void> validate() async {
    final missing = <String>[];

    // Supabase credentials (required)
    if (dotenv.env['SUPABASE_URL']?.isEmpty ?? true) {
      missing.add('SUPABASE_URL');
    }
    if (dotenv.env['SUPABASE_ANON_KEY']?.isEmpty ?? true) {
      missing.add('SUPABASE_ANON_KEY');
    }

    // Optional: API base URL (has default fallback)
    final apiBase = dotenv.env['API_BASE'];
    if (apiBase != null && apiBase.isNotEmpty) {
      AppLogger.debug('[SECRETS] API_BASE configured: $apiBase');
    } else {
      AppLogger.debug('[SECRETS] API_BASE not set, using default: http://localhost:8000');
    }

    // If any required secrets are missing, throw exception
    if (missing.isNotEmpty) {
      final error = 'Missing required environment variables: ${missing.join(", ")}\n'
          'Please ensure .env file is configured with all required secrets.\n'
          'See .env.example for required variables.';

      AppLogger.fatal('[SECRETS] Validation failed', error);
      throw SecretsException(error);
    }

    AppLogger.info('[SECRETS] ✅ All required secrets validated');
  }

  /// Check if secrets are configured (non-throwing version)
  static bool areSecretsConfigured() {
    try {
      final hasSupabaseUrl = dotenv.env['SUPABASE_URL']?.isNotEmpty ?? false;
      final hasSupabaseKey = dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty ?? false;
      return hasSupabaseUrl && hasSupabaseKey;
    } catch (e) {
      return false;
    }
  }

  /// Get secrets health status (for admin dashboard)
  static Map<String, bool> getSecretsHealth() {
    return {
      'SUPABASE_URL': dotenv.env['SUPABASE_URL']?.isNotEmpty ?? false,
      'SUPABASE_ANON_KEY': dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty ?? false,
      'API_BASE': dotenv.env['API_BASE']?.isNotEmpty ?? false,
    };
  }

  /// Mask secret values for logging (show first/last 4 chars only)
  static String maskSecret(String secret) {
    if (secret.length <= 8) {
      return '***';
    }
    return '${secret.substring(0, 4)}...${secret.substring(secret.length - 4)}';
  }
}

/// Exception thrown when required secrets are missing
class SecretsException implements Exception {
  final String message;
  SecretsException(this.message);

  @override
  String toString() => 'SecretsException: $message';
}
