import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_models.dart';
import 'dart:convert';

/// Secure storage service for sensitive authentication data
///
/// Uses flutter_secure_storage to securely store:
/// - Authentication tokens
/// - User credentials (Apple Sign-In)
/// - 2FA status
/// - User profile data
///
/// All data is encrypted at rest using platform-specific secure storage:
/// - iOS: Keychain
/// - Android: EncryptedSharedPreferences (AES-256)
/// - Web: Web Crypto API
class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._();
  SecureStorageService._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Storage keys
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyFamilyId = 'family_id';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserEmail = 'user_email';
  static const String _keyAppleUserId = 'apple_user_id';
  static const String _key2FAEnabled = '2fa_enabled';
  static const String _keyUserProfile = 'user_profile';
  static const String _keyLastLoginDate = 'last_login_date';

  // ===== Authentication Tokens =====

  Future<void> setAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  Future<void> setRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _keyRefreshToken);
  }

  Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ===== User Identity =====

  Future<void> setUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  Future<String?> getUserId() async {
    return _storage.read(key: _keyUserId);
  }

  Future<void> setFamilyId(String familyId) async {
    await _storage.write(key: _keyFamilyId, value: familyId);
  }

  Future<String?> getFamilyId() async {
    return _storage.read(key: _keyFamilyId);
  }

  Future<void> setUserRole(String role) async {
    await _storage.write(key: _keyUserRole, value: role);
  }

  Future<String?> getUserRole() async {
    return _storage.read(key: _keyUserRole);
  }

  Future<void> setUserEmail(String email) async {
    await _storage.write(key: _keyUserEmail, value: email);
  }

  Future<String?> getUserEmail() async {
    return _storage.read(key: _keyUserEmail);
  }

  // ===== Apple Sign-In =====

  Future<void> setAppleUserId(String appleUserId) async {
    await _storage.write(key: _keyAppleUserId, value: appleUserId);
  }

  Future<String?> getAppleUserId() async {
    return _storage.read(key: _keyAppleUserId);
  }

  Future<bool> hasAppleAccount() async {
    final appleId = await getAppleUserId();
    return appleId != null && appleId.isNotEmpty;
  }

  // ===== 2FA Status =====

  Future<void> set2FAEnabled(bool enabled) async {
    await _storage.write(key: _key2FAEnabled, value: enabled.toString());
  }

  Future<bool> is2FAEnabled() async {
    final value = await _storage.read(key: _key2FAEnabled);
    return value == 'true';
  }

  // ===== User Profile =====

  Future<void> setUserProfile(UserProfile profile) async {
    final json = jsonEncode(profile.toJson());
    await _storage.write(key: _keyUserProfile, value: json);
  }

  Future<UserProfile?> getUserProfile() async {
    final json = await _storage.read(key: _keyUserProfile);
    if (json == null || json.isEmpty) return null;

    try {
      final Map<String, dynamic> data = jsonDecode(json);
      return UserProfile.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  // ===== Session Management =====

  Future<void> setLastLoginDate(DateTime date) async {
    await _storage.write(key: _keyLastLoginDate, value: date.toIso8601String());
  }

  Future<DateTime?> getLastLoginDate() async {
    final value = await _storage.read(key: _keyLastLoginDate);
    if (value == null) return null;

    try {
      return DateTime.parse(value);
    } catch (e) {
      return null;
    }
  }

  // ===== Convenience Methods =====

  /// Store complete auth response after login
  Future<void> storeAuthResponse(AuthResponse auth) async {
    await Future.wait([
      setAccessToken(auth.accessToken),
      setRefreshToken(auth.refreshToken),
      setUserId(auth.userId),
      setFamilyId(auth.familyId),
      setUserRole(auth.role),
      if (auth.email != null) setUserEmail(auth.email!),
      setLastLoginDate(DateTime.now()),
    ]);
  }

  /// Store Apple Sign-In session data
  Future<void> storeAppleSignInSession({
    required AuthResponse auth,
    required String appleUserId,
  }) async {
    await Future.wait([
      storeAuthResponse(auth),
      setAppleUserId(appleUserId),
    ]);
  }

  /// Update 2FA status after setup/disable
  Future<void> update2FAStatus(bool enabled) async {
    await set2FAEnabled(enabled);

    // Update user profile if exists
    final profile = await getUserProfile();
    if (profile != null) {
      await setUserProfile(profile.copyWith(twoFAEnabled: enabled));
    }
  }

  // ===== Security Operations =====

  /// Clear all stored data (logout)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Clear only authentication tokens (keep user preferences)
  Future<void> clearAuthTokens() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
    ]);
  }

  /// Check if user session is valid
  Future<bool> hasValidSession() async {
    final token = await getAccessToken();
    final userId = await getUserId();
    return token != null &&
        token.isNotEmpty &&
        userId != null &&
        userId.isNotEmpty;
  }

  /// Get all stored keys (for debugging)
  Future<Map<String, String>> getAllData() async {
    return _storage.readAll();
  }

  /// Delete specific key
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Check if key exists
  Future<bool> containsKey(String key) async {
    final value = await _storage.read(key: key);
    return value != null;
  }
}
