/// Supabase Realtime Service
///
/// Manages real-time subscriptions for tasks and events with:
/// - Automatic reconnection on network restore
/// - Graceful offline degradation
/// - Conflict resolution with local Hive storage
/// - Rate limiting to prevent subscription spam

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_storage.dart';

/// Connection state for real-time subscriptions
enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Subscription status for individual channels
class SubscriptionStatus {
  final String channelName;
  final bool isSubscribed;
  final DateTime lastUpdate;

  SubscriptionStatus({
    required this.channelName,
    required this.isSubscribed,
    required this.lastUpdate,
  });
}

/// Real-time service for FamQuest
class SupabaseRealtimeService {
  static final SupabaseRealtimeService instance = SupabaseRealtimeService._();
  SupabaseRealtimeService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final FamQuestStorage _localStorage = FamQuestStorage.instance;

  // Channels
  RealtimeChannel? _tasksChannel;
  RealtimeChannel? _eventsChannel;
  RealtimeChannel? _pointsChannel;
  RealtimeChannel? _badgesChannel;
  RealtimeChannel? _familyChannel;

  // Connection state
  final _connectionStateController =
      StreamController<RealtimeConnectionState>.broadcast();
  Stream<RealtimeConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  RealtimeConnectionState _currentState = RealtimeConnectionState.disconnected;

  // Subscription status tracking
  final Map<String, SubscriptionStatus> _subscriptionStatuses = {};
  final _subscriptionStatusController =
      StreamController<Map<String, SubscriptionStatus>>.broadcast();
  Stream<Map<String, SubscriptionStatus>> get subscriptionStatusStream =>
      _subscriptionStatusController.stream;

  // Event streams for UI updates
  final _taskUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get taskUpdateStream => _taskUpdateController.stream;

  final _eventUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventUpdateStream => _eventUpdateController.stream;

  final _pointsUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get pointsUpdateStream => _pointsUpdateController.stream;

  final _badgeUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get badgeUpdateStream => _badgeUpdateController.stream;

  final _familyUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get familyUpdateStream => _familyUpdateController.stream;

  // Rate limiting
  DateTime? _lastTaskUpdate;
  DateTime? _lastEventUpdate;
  static const _rateLimitMillis = 500; // Min 500ms between updates

  // Reconnection strategy
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  static const _baseReconnectDelaySeconds = 2;

  RealtimeConnectionState get currentState => _currentState;

  /// Initialize real-time subscriptions for a family
  Future<void> initialize(String familyId, {String? userId}) async {
    try {
      _updateConnectionState(RealtimeConnectionState.connecting);

      // Unsubscribe from existing channels
      await unsubscribeAll();

      // Subscribe to all channels
      await _subscribeToTasks(familyId);
      await _subscribeToEvents(familyId);

      // User-specific subscriptions (if userId provided)
      if (userId != null) {
        await _subscribeToPoints(userId);
        await _subscribeToBadges(userId);
      }

      // Family-wide subscriptions
      await _subscribeToFamily(familyId);

      _updateConnectionState(RealtimeConnectionState.connected);
      _reconnectAttempts = 0;

      debugPrint('[RealtimeService] Initialized for family: $familyId');
    } catch (e) {
      debugPrint('[RealtimeService] Initialization error: $e');
      _updateConnectionState(RealtimeConnectionState.error);
      _scheduleReconnect(familyId);
    }
  }

  /// Subscribe to tasks table changes
  Future<void> _subscribeToTasks(String familyId) async {
    try {
      _tasksChannel = _supabase
          .channel('tasks:$familyId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tasks',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'family_id',
              value: familyId,
            ),
            callback: (payload) => _handleTaskChange(payload),
          )
          .subscribe();

      // Track subscription status
      _updateSubscriptionStatus('tasks', true);

      debugPrint('[RealtimeService] Subscribed to tasks for family: $familyId');
    } catch (e) {
      debugPrint('[RealtimeService] Task subscription error: $e');
      rethrow;
    }
  }

  /// Subscribe to events table changes
  Future<void> _subscribeToEvents(String familyId) async {
    try {
      _eventsChannel = _supabase
          .channel('events:$familyId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'family_id',
              value: familyId,
            ),
            callback: (payload) => _handleEventChange(payload),
          )
          .subscribe();

      // Track subscription status
      _updateSubscriptionStatus('events', true);

      debugPrint('[RealtimeService] Subscribed to events for family: $familyId');
    } catch (e) {
      debugPrint('[RealtimeService] Event subscription error: $e');
      rethrow;
    }
  }

  /// Subscribe to points ledger changes
  Future<void> _subscribeToPoints(String userId) async {
    try {
      _pointsChannel = _supabase
          .channel('points:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'points_ledger',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              debugPrint('[RealtimeService] Points earned: ${payload.newRecord}');
              _pointsUpdateController.add({
                'type': 'insert',
                'data': payload.newRecord,
              });
            },
          )
          .subscribe();

      _updateSubscriptionStatus('points', true);
      debugPrint('[RealtimeService] Subscribed to points for user: $userId');
    } catch (e) {
      debugPrint('[RealtimeService] Points subscription error: $e');
      rethrow;
    }
  }

  /// Subscribe to badge unlocks
  Future<void> _subscribeToBadges(String userId) async {
    try {
      _badgesChannel = _supabase
          .channel('badges:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'badges',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              debugPrint('[RealtimeService] Badge unlocked: ${payload.newRecord}');
              _badgeUpdateController.add({
                'type': 'insert',
                'data': payload.newRecord,
              });
            },
          )
          .subscribe();

      _updateSubscriptionStatus('badges', true);
      debugPrint('[RealtimeService] Subscribed to badges for user: $userId');
    } catch (e) {
      debugPrint('[RealtimeService] Badges subscription error: $e');
      rethrow;
    }
  }

  /// Subscribe to family member changes
  Future<void> _subscribeToFamily(String familyId) async {
    try {
      _familyChannel = _supabase
          .channel('family:$familyId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'users',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'family_id',
              value: familyId,
            ),
            callback: (payload) {
              debugPrint('[RealtimeService] Family member update: ${payload.eventType}');
              _familyUpdateController.add({
                'type': payload.eventType.name,
                'data': payload.newRecord,
                'old': payload.oldRecord,
              });
            },
          )
          .subscribe();

      _updateSubscriptionStatus('family', true);
      debugPrint('[RealtimeService] Subscribed to family members: $familyId');
    } catch (e) {
      debugPrint('[RealtimeService] Family subscription error: $e');
      rethrow;
    }
  }

  /// Handle task change events (INSERT, UPDATE, DELETE)
  void _handleTaskChange(PostgresChangePayload payload) async {
    // Rate limiting
    final now = DateTime.now();
    if (_lastTaskUpdate != null &&
        now.difference(_lastTaskUpdate!).inMilliseconds < _rateLimitMillis) {
      debugPrint('[RealtimeService] Task update rate limited');
      return;
    }
    _lastTaskUpdate = now;

    try {
      final eventType = payload.eventType;
      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;

      debugPrint('[RealtimeService] Task change: $eventType');

      switch (eventType) {
        case PostgresChangeEvent.insert:
          if (newRecord.isNotEmpty) {
            await _handleTaskInsert(newRecord);
          }
          break;

        case PostgresChangeEvent.update:
          if (newRecord.isNotEmpty) {
            await _handleTaskUpdate(newRecord, oldRecord);
          }
          break;

        case PostgresChangeEvent.delete:
          if (oldRecord.isNotEmpty) {
            await _handleTaskDelete(oldRecord);
          }
          break;

        default:
          debugPrint('[RealtimeService] Unknown task event: $eventType');
      }
    } catch (e) {
      debugPrint('[RealtimeService] Task change handler error: $e');
    }
  }

  /// Handle event change events (INSERT, UPDATE, DELETE)
  void _handleEventChange(PostgresChangePayload payload) async {
    // Rate limiting
    final now = DateTime.now();
    if (_lastEventUpdate != null &&
        now.difference(_lastEventUpdate!).inMilliseconds < _rateLimitMillis) {
      debugPrint('[RealtimeService] Event update rate limited');
      return;
    }
    _lastEventUpdate = now;

    try {
      final eventType = payload.eventType;
      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;

      debugPrint('[RealtimeService] Event change: $eventType');

      switch (eventType) {
        case PostgresChangeEvent.insert:
          if (newRecord.isNotEmpty) {
            await _handleEventInsert(newRecord);
          }
          break;

        case PostgresChangeEvent.update:
          if (newRecord.isNotEmpty) {
            await _handleEventUpdate(newRecord, oldRecord);
          }
          break;

        case PostgresChangeEvent.delete:
          if (oldRecord.isNotEmpty) {
            await _handleEventDelete(oldRecord);
          }
          break;

        default:
          debugPrint('[RealtimeService] Unknown event type: $eventType');
      }
    } catch (e) {
      debugPrint('[RealtimeService] Event change handler error: $e');
    }
  }

  /// Handle task insert
  Future<void> _handleTaskInsert(Map<String, dynamic> record) async {
    try {
      final taskId = record['id'] as String;

      // Check if task already exists locally (avoid duplicates)
      final existingTask = await _localStorage.get('tasks', taskId);
      if (existingTask != null) {
        debugPrint('[RealtimeService] Task already exists locally: $taskId');
        return;
      }

      // Store in local storage
      await _localStorage.put('tasks', taskId, _normalizeTaskRecord(record));

      // Notify UI
      _taskUpdateController.add({
        'type': 'insert',
        'data': record,
      });

      debugPrint('[RealtimeService] Task inserted: $taskId');
    } catch (e) {
      debugPrint('[RealtimeService] Task insert error: $e');
    }
  }

  /// Handle task update with conflict resolution
  Future<void> _handleTaskUpdate(
    Map<String, dynamic> newRecord,
    Map<String, dynamic> oldRecord,
  ) async {
    try {
      final taskId = newRecord['id'] as String;
      final serverVersion = newRecord['version'] as int? ?? 1;

      // Check local version for conflict resolution
      final localTask = await _localStorage.get('tasks', taskId);
      if (localTask != null) {
        final localVersion = localTask['version'] as int? ?? 1;
        final isDirty = localTask['isDirty'] as bool? ?? false;

        // Conflict: local changes not synced yet
        if (isDirty && localVersion >= serverVersion) {
          debugPrint(
            '[RealtimeService] Task conflict detected: $taskId (local: $localVersion, server: $serverVersion)',
          );
          // Keep local changes, let sync queue handle it
          return;
        }
      }

      // Update local storage with server data
      await _localStorage.put('tasks', taskId, _normalizeTaskRecord(newRecord));

      // Notify UI
      _taskUpdateController.add({
        'type': 'update',
        'data': newRecord,
        'old': oldRecord,
      });

      debugPrint('[RealtimeService] Task updated: $taskId');
    } catch (e) {
      debugPrint('[RealtimeService] Task update error: $e');
    }
  }

  /// Handle task delete
  Future<void> _handleTaskDelete(Map<String, dynamic> record) async {
    try {
      final taskId = record['id'] as String;

      // Remove from local storage
      await _localStorage.delete('tasks', taskId);

      // Notify UI
      _taskUpdateController.add({
        'type': 'delete',
        'data': record,
      });

      debugPrint('[RealtimeService] Task deleted: $taskId');
    } catch (e) {
      debugPrint('[RealtimeService] Task delete error: $e');
    }
  }

  /// Handle event insert
  Future<void> _handleEventInsert(Map<String, dynamic> record) async {
    try {
      final eventId = record['id'] as String;

      // Check if event already exists locally
      final existingEvent = await _localStorage.get('events', eventId);
      if (existingEvent != null) {
        debugPrint('[RealtimeService] Event already exists locally: $eventId');
        return;
      }

      // Store in local storage
      await _localStorage.put('events', eventId, _normalizeEventRecord(record));

      // Notify UI
      _eventUpdateController.add({
        'type': 'insert',
        'data': record,
      });

      debugPrint('[RealtimeService] Event inserted: $eventId');
    } catch (e) {
      debugPrint('[RealtimeService] Event insert error: $e');
    }
  }

  /// Handle event update with conflict resolution
  Future<void> _handleEventUpdate(
    Map<String, dynamic> newRecord,
    Map<String, dynamic> oldRecord,
  ) async {
    try {
      final eventId = newRecord['id'] as String;
      final serverVersion = newRecord['version'] as int? ?? 1;

      // Check local version for conflict resolution
      final localEvent = await _localStorage.get('events', eventId);
      if (localEvent != null) {
        final localVersion = localEvent['version'] as int? ?? 1;
        final isDirty = localEvent['isDirty'] as bool? ?? false;

        // Conflict: local changes not synced yet
        if (isDirty && localVersion >= serverVersion) {
          debugPrint(
            '[RealtimeService] Event conflict detected: $eventId (local: $localVersion, server: $serverVersion)',
          );
          // Keep local changes, let sync queue handle it
          return;
        }
      }

      // Update local storage with server data
      await _localStorage.put('events', eventId, _normalizeEventRecord(newRecord));

      // Notify UI
      _eventUpdateController.add({
        'type': 'update',
        'data': newRecord,
        'old': oldRecord,
      });

      debugPrint('[RealtimeService] Event updated: $eventId');
    } catch (e) {
      debugPrint('[RealtimeService] Event update error: $e');
    }
  }

  /// Handle event delete
  Future<void> _handleEventDelete(Map<String, dynamic> record) async {
    try {
      final eventId = record['id'] as String;

      // Remove from local storage
      await _localStorage.delete('events', eventId);

      // Notify UI
      _eventUpdateController.add({
        'type': 'delete',
        'data': record,
      });

      debugPrint('[RealtimeService] Event deleted: $eventId');
    } catch (e) {
      debugPrint('[RealtimeService] Event delete error: $e');
    }
  }

  /// Normalize task record (convert snake_case to camelCase)
  Map<String, dynamic> _normalizeTaskRecord(Map<String, dynamic> record) {
    return {
      'id': record['id'],
      'familyId': record['family_id'],
      'title': record['title'],
      'description': record['description'],
      'category': record['category'],
      'frequency': record['frequency'],
      'rrule': record['rrule'],
      'due': record['due'],
      'assignees': record['assignees'] ?? [],
      'claimable': record['claimable'] ?? false,
      'claimedBy': record['claimed_by'],
      'claimExpiry': record['claim_expiry'],
      'points': record['points'] ?? 10,
      'photoRequired': record['photo_required'] ?? false,
      'parentApproval': record['parent_approval'] ?? false,
      'status': record['status'] ?? 'open',
      'proofPhotos': record['proof_photos'] ?? [],
      'priority': record['priority'] ?? 'medium',
      'estimatedMinutes': record['estimated_minutes'] ?? 0,
      'createdBy': record['created_by'],
      'createdAt': record['created_at'],
      'updatedAt': record['updated_at'],
      'version': record['version'] ?? 1,
      'isDirty': false, // Server data is clean
    };
  }

  /// Normalize event record (convert snake_case to camelCase)
  Map<String, dynamic> _normalizeEventRecord(Map<String, dynamic> record) {
    return {
      'id': record['id'],
      'familyId': record['family_id'],
      'title': record['title'],
      'description': record['description'],
      'startTime': record['start_time'],
      'endTime': record['end_time'],
      'isAllDay': record['is_all_day'] ?? false,
      'attendees': record['attendees'] ?? [],
      'category': record['category'] ?? 'other',
      'color': record['color'] ?? '#2196F3',
      'recurrence': record['recurrence'],
      'createdBy': record['created_by'],
      'createdAt': record['created_at'],
      'updatedAt': record['updated_at'],
      'version': record['version'] ?? 1,
      'lastModifiedBy': record['last_modified_by'] ?? record['created_by'],
      'isDirty': false, // Server data is clean
    };
  }

  /// Update connection state
  void _updateConnectionState(RealtimeConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _connectionStateController.add(newState);
      debugPrint('[RealtimeService] Connection state: $newState');
    }
  }

  /// Update subscription status
  void _updateSubscriptionStatus(String channelName, bool isSubscribed) {
    _subscriptionStatuses[channelName] = SubscriptionStatus(
      channelName: channelName,
      isSubscribed: isSubscribed,
      lastUpdate: DateTime.now(),
    );
    _subscriptionStatusController.add(Map.from(_subscriptionStatuses));
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect(String familyId) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[RealtimeService] Max reconnect attempts reached');
      _updateConnectionState(RealtimeConnectionState.error);
      return;
    }

    _reconnectAttempts++;
    final delaySeconds = _baseReconnectDelaySeconds * _reconnectAttempts;

    debugPrint(
      '[RealtimeService] Scheduling reconnect in ${delaySeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _updateConnectionState(RealtimeConnectionState.reconnecting);
      initialize(familyId);
    });
  }

  /// Unsubscribe from all channels
  Future<void> unsubscribeAll() async {
    try {
      if (_tasksChannel != null) {
        await _supabase.removeChannel(_tasksChannel!);
        _tasksChannel = null;
        debugPrint('[RealtimeService] Unsubscribed from tasks');
      }

      if (_eventsChannel != null) {
        await _supabase.removeChannel(_eventsChannel!);
        _eventsChannel = null;
        debugPrint('[RealtimeService] Unsubscribed from events');
      }

      if (_pointsChannel != null) {
        await _supabase.removeChannel(_pointsChannel!);
        _pointsChannel = null;
        debugPrint('[RealtimeService] Unsubscribed from points');
      }

      if (_badgesChannel != null) {
        await _supabase.removeChannel(_badgesChannel!);
        _badgesChannel = null;
        debugPrint('[RealtimeService] Unsubscribed from badges');
      }

      if (_familyChannel != null) {
        await _supabase.removeChannel(_familyChannel!);
        _familyChannel = null;
        debugPrint('[RealtimeService] Unsubscribed from family');
      }

      _subscriptionStatuses.clear();
      _subscriptionStatusController.add({});
      _updateConnectionState(RealtimeConnectionState.disconnected);

      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;
    } catch (e) {
      debugPrint('[RealtimeService] Unsubscribe error: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    unsubscribeAll();
    _connectionStateController.close();
    _subscriptionStatusController.close();
    _taskUpdateController.close();
    _eventUpdateController.close();
    _pointsUpdateController.close();
    _badgeUpdateController.close();
    _familyUpdateController.close();
    _reconnectTimer?.cancel();
  }
}
