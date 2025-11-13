/// Authentication data models for type-safe API interactions
///
/// Provides strongly-typed models for:
/// - User authentication
/// - Apple Sign-In credentials
/// - 2FA setup and verification
/// - Backup codes management

/// User authentication response
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String familyId;
  final String role;
  final bool requires2FA;
  final String? email;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.familyId,
    required this.role,
    this.requires2FA = false,
    this.email,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      userId: json['userId'] ?? json['id'] ?? '',
      familyId: json['familyId'] ?? '',
      role: json['role'] ?? 'child',
      requires2FA: json['requires2FA'] ?? false,
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'userId': userId,
      'familyId': familyId,
      'role': role,
      'requires2FA': requires2FA,
      'email': email,
    };
  }
}

/// Apple Sign-In credential data
class AppleSignInCredential {
  final String authorizationCode;
  final String identityToken;
  final String userIdentifier;
  final String? email;
  final String? givenName;
  final String? familyName;

  AppleSignInCredential({
    required this.authorizationCode,
    required this.identityToken,
    required this.userIdentifier,
    this.email,
    this.givenName,
    this.familyName,
  });

  Map<String, dynamic> toJson() {
    return {
      'authorization_code': authorizationCode,
      'identity_token': identityToken,
      'user_identifier': userIdentifier,
      'email': email,
      'given_name': givenName,
      'family_name': familyName,
    };
  }
}

/// 2FA setup response from backend
class TwoFASetupResponse {
  final String secret;
  final String otpauthUrl;
  final String qrCodeUrl;

  TwoFASetupResponse({
    required this.secret,
    required this.otpauthUrl,
    required this.qrCodeUrl,
  });

  factory TwoFASetupResponse.fromJson(Map<String, dynamic> json) {
    return TwoFASetupResponse(
      secret: json['secret'] ?? '',
      otpauthUrl: json['otpauth_url'] ?? json['otpauthUrl'] ?? '',
      qrCodeUrl: json['qr_code_url'] ?? json['qrCodeUrl'] ?? '',
    );
  }
}

/// 2FA verification response
class TwoFAVerifyResponse {
  final bool success;
  final List<String>? backupCodes;
  final String? message;

  TwoFAVerifyResponse({
    required this.success,
    this.backupCodes,
    this.message,
  });

  factory TwoFAVerifyResponse.fromJson(Map<String, dynamic> json) {
    return TwoFAVerifyResponse(
      success: json['success'] ?? false,
      backupCodes: json['backup_codes'] != null
          ? List<String>.from(json['backup_codes'])
          : null,
      message: json['message'],
    );
  }
}

/// 2FA status information
class TwoFAStatus {
  final bool enabled;
  final DateTime? enabledAt;
  final int? backupCodesRemaining;

  TwoFAStatus({
    required this.enabled,
    this.enabledAt,
    this.backupCodesRemaining,
  });

  factory TwoFAStatus.fromJson(Map<String, dynamic> json) {
    return TwoFAStatus(
      enabled: json['enabled'] ?? false,
      enabledAt: json['enabledAt'] != null || json['enabled_at'] != null
          ? DateTime.parse(json['enabledAt'] ?? json['enabled_at'])
          : null,
      backupCodesRemaining: json['backup_codes_remaining'] ??
          json['backupCodesRemaining'],
    );
  }
}

/// Backup codes response
class BackupCodesResponse {
  final List<String> backupCodes;
  final DateTime generatedAt;

  BackupCodesResponse({
    required this.backupCodes,
    required this.generatedAt,
  });

  factory BackupCodesResponse.fromJson(Map<String, dynamic> json) {
    return BackupCodesResponse(
      backupCodes: List<String>.from(json['backup_codes'] ?? []),
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'])
          : DateTime.now(),
    );
  }
}

/// User profile data
class UserProfile {
  final String id;
  final String familyId;
  final String email;
  final String displayName;
  final String role;
  final String? avatarUrl;
  final bool twoFAEnabled;
  final DateTime? lastLogin;
  final String locale;
  final String theme;

  UserProfile({
    required this.id,
    required this.familyId,
    required this.email,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.twoFAEnabled = false,
    this.lastLogin,
    this.locale = 'nl',
    this.theme = 'minimal',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      familyId: json['familyId'] ?? json['family_id'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? json['display_name'] ?? '',
      role: json['role'] ?? 'child',
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
      twoFAEnabled: json['twoFAEnabled'] ?? json['two_fa_enabled'] ?? false,
      lastLogin: json['lastLogin'] != null || json['last_login'] != null
          ? DateTime.parse(json['lastLogin'] ?? json['last_login'])
          : null,
      locale: json['locale'] ?? 'nl',
      theme: json['theme'] ?? 'minimal',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'email': email,
      'displayName': displayName,
      'role': role,
      'avatarUrl': avatarUrl,
      'twoFAEnabled': twoFAEnabled,
      'lastLogin': lastLogin?.toIso8601String(),
      'locale': locale,
      'theme': theme,
    };
  }

  /// Check if user has permission for action based on role
  bool hasPermission(String action) {
    switch (role) {
      case 'parent':
        return true; // Parents have all permissions
      case 'teen':
        return ['view', 'create_task', 'edit_own', 'complete_task']
            .contains(action);
      case 'child':
        return ['view', 'complete_task'].contains(action);
      case 'helper':
        return ['view', 'help'].contains(action);
      default:
        return false;
    }
  }

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? id,
    String? familyId,
    String? email,
    String? displayName,
    String? role,
    String? avatarUrl,
    bool? twoFAEnabled,
    DateTime? lastLogin,
    String? locale,
    String? theme,
  }) {
    return UserProfile(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      twoFAEnabled: twoFAEnabled ?? this.twoFAEnabled,
      lastLogin: lastLogin ?? this.lastLogin,
      locale: locale ?? this.locale,
      theme: theme ?? this.theme,
    );
  }
}
