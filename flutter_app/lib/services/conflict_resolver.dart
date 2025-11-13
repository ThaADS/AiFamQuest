import 'dart:async';
import 'dart:math' as math;

/// Conflict resolver service for offline sync conflicts
/// Implements PRD conflict resolution rules
class ConflictResolver {
  static final ConflictResolver instance = ConflictResolver._();
  ConflictResolver._();

  /// Resolve conflict between client and server state
  /// Returns ConflictResolution with resolution strategy
  Future<ConflictResolution> resolve(ConflictData conflict) async {
    final clientData = conflict.clientData;
    final serverData = conflict.serverData;
    final entityType = conflict.entityType;

    // Rule 1: Task Status Priority (done > pendingApproval > open)
    if (entityType == 'task' && _hasStatusConflict(clientData, serverData)) {
      final resolution = _resolveTaskStatus(clientData, serverData);
      if (resolution != null) {
        return resolution;
      }
    }

    // Rule 2: Delete Wins (if either side deleted, apply delete)
    if (_hasDeleteConflict(clientData, serverData)) {
      return ConflictResolution(
        strategy: ResolutionStrategy.deleteWins,
        resolvedData: {'isDeleted': true},
        needsManualReview: false,
        explanation: 'Delete wins: Entity was deleted on one side',
      );
    }

    // Rule 3: Last Writer Wins (compare timestamps)
    final clientTimestamp = DateTime.parse(clientData['updatedAt']);
    final serverTimestamp = DateTime.parse(serverData['updatedAt']);

    if (clientTimestamp.isAfter(serverTimestamp)) {
      return ConflictResolution(
        strategy: ResolutionStrategy.lastWriterWins,
        resolvedData: clientData,
        needsManualReview: false,
        explanation: 'Client changes are newer (${clientTimestamp.toIso8601String()})',
      );
    } else if (serverTimestamp.isAfter(clientTimestamp)) {
      return ConflictResolution(
        strategy: ResolutionStrategy.lastWriterWins,
        resolvedData: serverData,
        needsManualReview: false,
        explanation: 'Server changes are newer (${serverTimestamp.toIso8601String()})',
      );
    }

    // Rule 4: Manual Resolution Required
    // Timestamps are equal or conflict is too complex
    return ConflictResolution(
      strategy: ResolutionStrategy.manualReview,
      resolvedData: null,
      needsManualReview: true,
      explanation: 'Conflict requires manual review (equal timestamps or complex conflict)',
    );
  }

  /// Check if there's a status conflict
  bool _hasStatusConflict(Map<String, dynamic> clientData, Map<String, dynamic> serverData) {
    return clientData['status'] != null &&
        serverData['status'] != null &&
        clientData['status'] != serverData['status'];
  }

  /// Check if there's a delete conflict
  bool _hasDeleteConflict(Map<String, dynamic> clientData, Map<String, dynamic> serverData) {
    return (clientData['isDeleted'] == true) || (serverData['isDeleted'] == true);
  }

  /// Resolve task status conflict using PRD priority rules
  ConflictResolution? _resolveTaskStatus(
    Map<String, dynamic> clientData,
    Map<String, dynamic> serverData,
  ) {
    final clientStatus = clientData['status'] as String;
    final serverStatus = serverData['status'] as String;

    // Priority: done > pendingApproval > open
    final statusPriority = {
      'done': 3,
      'pendingApproval': 2,
      'open': 1,
    };

    final clientPriority = statusPriority[clientStatus] ?? 0;
    final serverPriority = statusPriority[serverStatus] ?? 0;

    if (clientPriority > serverPriority) {
      return ConflictResolution(
        strategy: ResolutionStrategy.taskStatusPriority,
        resolvedData: clientData,
        needsManualReview: false,
        explanation: 'Task status: $clientStatus beats $serverStatus (PRD priority)',
      );
    } else if (serverPriority > clientPriority) {
      return ConflictResolution(
        strategy: ResolutionStrategy.taskStatusPriority,
        resolvedData: serverData,
        needsManualReview: false,
        explanation: 'Task status: $serverStatus beats $clientStatus (PRD priority)',
      );
    }

    return null; // Equal priority, fall through to other rules
  }

  /// Merge conflict by combining both sides (for specific fields)
  Future<ConflictResolution> merge(ConflictData conflict) async {
    final clientData = conflict.clientData;
    final serverData = conflict.serverData;
    final merged = <String, dynamic>{};

    // Start with server data as base
    merged.addAll(serverData);

    // Merge strategies by field type
    for (final key in clientData.keys) {
      if (!serverData.containsKey(key)) {
        // Client has new field
        merged[key] = clientData[key];
      } else if (clientData[key] != serverData[key]) {
        // Conflict on this field
        merged[key] = _mergeField(key, clientData[key], serverData[key]);
      }
    }

    // Use latest timestamp
    final clientTimestamp = DateTime.parse(clientData['updatedAt']);
    final serverTimestamp = DateTime.parse(serverData['updatedAt']);
    merged['updatedAt'] = clientTimestamp.isAfter(serverTimestamp)
        ? clientData['updatedAt']
        : serverData['updatedAt'];

    // Increment version
    merged['version'] = math.max<int>(
      clientData['version'] as int? ?? 0,
      serverData['version'] as int? ?? 0,
    ) + 1;

    return ConflictResolution(
      strategy: ResolutionStrategy.merge,
      resolvedData: merged,
      needsManualReview: false,
      explanation: 'Merged client and server changes',
    );
  }

  /// Merge individual field based on type
  dynamic _mergeField(String key, dynamic clientValue, dynamic serverValue) {
    // List merging (union)
    if (clientValue is List && serverValue is List) {
      return [...clientValue, ...serverValue].toSet().toList();
    }

    // Numeric merging (max)
    if (clientValue is num && serverValue is num) {
      return math.max(clientValue, serverValue);
    }

    // String merging (concatenate with separator)
    if (clientValue is String && serverValue is String) {
      if (clientValue == serverValue) return clientValue;
      return '$clientValue | $serverValue';
    }

    // Default: keep server value
    return serverValue;
  }

  /// Analyze conflict to determine if it can be merged
  bool canMerge(ConflictData conflict) {
    final clientData = conflict.clientData;
    final serverData = conflict.serverData;

    // Cannot merge if deleted
    if (_hasDeleteConflict(clientData, serverData)) {
      return false;
    }

    // Cannot merge if critical fields conflict (e.g., task status)
    if (conflict.entityType == 'task' && _hasStatusConflict(clientData, serverData)) {
      return false;
    }

    // Can merge if only non-critical fields differ
    return true;
  }

  /// Get diff between client and server data
  Map<String, ConflictField> getDiff(ConflictData conflict) {
    final clientData = conflict.clientData;
    final serverData = conflict.serverData;
    final diff = <String, ConflictField>{};

    final allKeys = {...clientData.keys, ...serverData.keys};

    for (final key in allKeys) {
      if (key == 'version' || key == 'updatedAt' || key == 'isDirty') {
        continue; // Skip metadata fields
      }

      final clientValue = clientData[key];
      final serverValue = serverData[key];

      if (clientValue != serverValue) {
        diff[key] = ConflictField(
          fieldName: key,
          clientValue: clientValue,
          serverValue: serverValue,
        );
      }
    }

    return diff;
  }
}

// ========== Models ==========

/// Conflict data from sync
class ConflictData {
  final String id;
  final String entityType;
  final String entityId;
  final int clientVersion;
  final int serverVersion;
  final Map<String, dynamic> clientData;
  final Map<String, dynamic> serverData;
  final String conflictType;

  ConflictData({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.clientVersion,
    required this.serverVersion,
    required this.clientData,
    required this.serverData,
    required this.conflictType,
  });

  factory ConflictData.fromJson(Map<String, dynamic> json) {
    return ConflictData(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      entityType: json['entityType'],
      entityId: json['entityId'],
      clientVersion: json['clientVersion'],
      serverVersion: json['serverVersion'],
      clientData: Map<String, dynamic>.from(json['clientData']),
      serverData: Map<String, dynamic>.from(json['serverData']),
      conflictType: json['conflictType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'clientVersion': clientVersion,
      'serverVersion': serverVersion,
      'clientData': clientData,
      'serverData': serverData,
      'conflictType': conflictType,
    };
  }
}

/// Conflict resolution result
class ConflictResolution {
  final ResolutionStrategy strategy;
  final Map<String, dynamic>? resolvedData;
  final bool needsManualReview;
  final String explanation;

  ConflictResolution({
    required this.strategy,
    required this.resolvedData,
    required this.needsManualReview,
    required this.explanation,
  });
}

/// Resolution strategies
enum ResolutionStrategy {
  taskStatusPriority, // Rule 1: done > pendingApproval > open
  deleteWins, // Rule 2: Delete wins
  lastWriterWins, // Rule 3: Newest timestamp wins
  merge, // Merge both sides
  manualReview, // User must choose
}

/// Individual field conflict
class ConflictField {
  final String fieldName;
  final dynamic clientValue;
  final dynamic serverValue;

  ConflictField({
    required this.fieldName,
    required this.clientValue,
    required this.serverValue,
  });

  bool get hasConflict => clientValue != serverValue;
}
