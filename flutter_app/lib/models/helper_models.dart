/// Helper role data models for external help management
///
/// Provides strongly-typed models for:
/// - Helper invites and access codes
/// - Helper permissions and duration
/// - Active helper tracking

/// Represents a helper invite with access code
class HelperInvite {
  final String id;
  final String code;
  final String familyId;
  final String familyName;
  final String inviterName;
  final String helperName;
  final String helperEmail;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime expiresAt;
  final HelperPermissions permissions;
  final bool isActive;
  final DateTime? acceptedAt;

  HelperInvite({
    required this.id,
    required this.code,
    required this.familyId,
    required this.familyName,
    required this.inviterName,
    required this.helperName,
    required this.helperEmail,
    required this.startDate,
    required this.endDate,
    required this.expiresAt,
    required this.permissions,
    this.isActive = true,
    this.acceptedAt,
  });

  factory HelperInvite.fromJson(Map<String, dynamic> json) {
    return HelperInvite(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      familyId: json['family_id'] ?? '',
      familyName: json['family_name'] ?? '',
      inviterName: json['inviter_name'] ?? '',
      helperName: json['helper_name'] ?? '',
      helperEmail: json['helper_email'] ?? '',
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['end_date'] ?? DateTime.now().add(Duration(days: 30)).toIso8601String()),
      expiresAt: DateTime.parse(json['expires_at'] ?? DateTime.now().add(Duration(days: 7)).toIso8601String()),
      permissions: json['permissions'] != null
          ? HelperPermissions.fromJson(json['permissions'] as Map<String, dynamic>)
          : HelperPermissions(),
      isActive: json['is_active'] ?? true,
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'family_id': familyId,
      'family_name': familyName,
      'inviter_name': inviterName,
      'helper_name': helperName,
      'helper_email': helperEmail,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'permissions': permissions.toJson(),
      'is_active': isActive,
      'accepted_at': acceptedAt?.toIso8601String(),
    };
  }

  /// Check if invite is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if helper access period is active
  bool get isAccessActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate) && isActive && !isExpired;
  }

  /// Get days remaining until expiry
  int get daysUntilExpiry => expiresAt.difference(DateTime.now()).inDays;
}

/// Helper permissions configuration
class HelperPermissions {
  final bool canViewAssignedTasks;
  final bool canCompleteTasks;
  final bool canUploadPhotos;
  final bool canViewPoints;

  HelperPermissions({
    this.canViewAssignedTasks = true,
    this.canCompleteTasks = true,
    this.canUploadPhotos = true,
    this.canViewPoints = false,
  });

  factory HelperPermissions.fromJson(Map<String, dynamic> json) {
    return HelperPermissions(
      canViewAssignedTasks: json['can_view_assigned_tasks'] ?? true,
      canCompleteTasks: json['can_complete_tasks'] ?? true,
      canUploadPhotos: json['can_upload_photos'] ?? true,
      canViewPoints: json['can_view_points'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'can_view_assigned_tasks': canViewAssignedTasks,
      'can_complete_tasks': canCompleteTasks,
      'can_upload_photos': canUploadPhotos,
      'can_view_points': canViewPoints,
    };
  }

  HelperPermissions copyWith({
    bool? canViewAssignedTasks,
    bool? canCompleteTasks,
    bool? canUploadPhotos,
    bool? canViewPoints,
  }) {
    return HelperPermissions(
      canViewAssignedTasks: canViewAssignedTasks ?? this.canViewAssignedTasks,
      canCompleteTasks: canCompleteTasks ?? this.canCompleteTasks,
      canUploadPhotos: canUploadPhotos ?? this.canUploadPhotos,
      canViewPoints: canViewPoints ?? this.canViewPoints,
    );
  }
}

/// Active helper user data
class HelperUser {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  final DateTime activeUntil;
  final int tasksAssigned;
  final DateTime? lastSeen;
  final HelperPermissions permissions;

  HelperUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    required this.activeUntil,
    this.tasksAssigned = 0,
    this.lastSeen,
    required this.permissions,
  });

  factory HelperUser.fromJson(Map<String, dynamic> json) {
    return HelperUser(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'],
      activeUntil: DateTime.parse(json['active_until'] ?? DateTime.now().add(Duration(days: 30)).toIso8601String()),
      tasksAssigned: json['tasks_assigned'] ?? 0,
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
      permissions: json['permissions'] != null
          ? HelperPermissions.fromJson(json['permissions'] as Map<String, dynamic>)
          : HelperPermissions(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'active_until': activeUntil.toIso8601String(),
      'tasks_assigned': tasksAssigned,
      'last_seen': lastSeen?.toIso8601String(),
      'permissions': permissions.toJson(),
    };
  }

  /// Check if helper is currently active
  bool get isActive => DateTime.now().isBefore(activeUntil);

  /// Get days remaining of access
  int get daysRemaining => activeUntil.difference(DateTime.now()).inDays;
}

/// Helper invite creation request
class CreateHelperInviteRequest {
  final String helperName;
  final String helperEmail;
  final DateTime startDate;
  final DateTime endDate;
  final HelperPermissions permissions;

  CreateHelperInviteRequest({
    required this.helperName,
    required this.helperEmail,
    required this.startDate,
    required this.endDate,
    required this.permissions,
  });

  Map<String, dynamic> toJson() {
    return {
      'helper_name': helperName,
      'helper_email': helperEmail,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'permissions': permissions.toJson(),
    };
  }
}
