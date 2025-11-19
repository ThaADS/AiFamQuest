import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/local_storage.dart';
import '../../services/realtime_service.dart';
import '../../api/client.dart';
import '../../services/sync_queue.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_logger.dart';

/// Calendar event model
class CalendarEvent {
  final String id;
  final String familyId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final List<String> attendees;
  final String category; // school, sport, appointment, family, other
  final String color; // hex color
  final String? location; // event location (optional)
  final RecurrenceRule? recurrence;
  final bool isDirty;
  final int version;
  final DateTime updatedAt;
  final String lastModifiedBy;

  CalendarEvent({
    required this.id,
    required this.familyId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.attendees = const [],
    this.category = 'other',
    this.color = '#2196F3',
    this.location,
    this.recurrence,
    this.isDirty = false,
    this.version = 1,
    required this.updatedAt,
    required this.lastModifiedBy,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      familyId: json['familyId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      isAllDay: json['isAllDay'] as bool? ?? false,
      attendees: (json['attendees'] as List?)?.cast<String>() ?? [],
      category: json['category'] as String? ?? 'other',
      color: json['color'] as String? ?? '#2196F3',
      location: json['location'] as String?,
      recurrence: json['recurrence'] != null
          ? RecurrenceRule.fromJson(json['recurrence'])
          : null,
      isDirty: json['isDirty'] as bool? ?? false,
      version: json['version'] as int? ?? 1,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastModifiedBy: json['lastModifiedBy'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'isAllDay': isAllDay,
      'attendees': attendees,
      'category': category,
      'color': color,
      'location': location,
      'recurrence': recurrence?.toJson(),
      'isDirty': isDirty,
      'version': version,
      'updatedAt': updatedAt.toIso8601String(),
      'lastModifiedBy': lastModifiedBy,
    };
  }

  CalendarEvent copyWith({
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    List<String>? attendees,
    String? category,
    String? color,
    String? location,
    RecurrenceRule? recurrence,
    bool clearRecurrence = false,
    bool clearLocation = false,
  }) {
    return CalendarEvent(
      id: id,
      familyId: familyId,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      attendees: attendees ?? this.attendees,
      category: category ?? this.category,
      color: color ?? this.color,
      location: clearLocation ? null : (location ?? this.location),
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      isDirty: true,
      version: version + 1,
      updatedAt: DateTime.now().toUtc(),
      lastModifiedBy: lastModifiedBy,
    );
  }
}

/// Recurrence rule model
class RecurrenceRule {
  final String frequency; // daily, weekly, monthly, custom
  final int? interval; // every N days/weeks/months
  final List<int>? weekdays; // 1=Monday, 7=Sunday
  final DateTime? until; // end date
  final int? count; // number of occurrences

  RecurrenceRule({
    required this.frequency,
    this.interval,
    this.weekdays,
    this.until,
    this.count,
  });

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      frequency: json['frequency'] as String,
      interval: json['interval'] as int?,
      weekdays: (json['weekdays'] as List?)?.cast<int>(),
      until:
          json['until'] != null ? DateTime.parse(json['until'] as String) : null,
      count: json['count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'interval': interval,
      'weekdays': weekdays,
      'until': until?.toIso8601String(),
      'count': count,
    };
  }

  String getDescription() {
    switch (frequency) {
      case 'daily':
        return 'Repeats daily';
      case 'weekly':
        if (weekdays != null && weekdays!.isNotEmpty) {
          final days = weekdays!
              .map((d) => ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'][d - 1])
              .join(', ');
          return 'Repeats every $days';
        }
        return 'Repeats weekly';
      case 'monthly':
        return 'Repeats monthly';
      default:
        return 'Custom recurrence';
    }
  }
}

/// Calendar state
class CalendarState {
  final List<CalendarEvent> events;
  final bool isLoading;
  final String? error;
  final DateTime focusedDate;
  final bool isRealtimeConnected;

  CalendarState({
    this.events = const [],
    this.isLoading = false,
    this.error,
    required this.focusedDate,
    this.isRealtimeConnected = false,
  });

  CalendarState copyWith({
    List<CalendarEvent>? events,
    bool? isLoading,
    String? error,
    DateTime? focusedDate,
    bool? isRealtimeConnected,
  }) {
    return CalendarState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      focusedDate: focusedDate ?? this.focusedDate,
      isRealtimeConnected: isRealtimeConnected ?? this.isRealtimeConnected,
    );
  }
}

/// Calendar provider
class CalendarNotifier extends StateNotifier<CalendarState> {
  final FamQuestStorage _localStorage;
  // ignore: unused_field
  final ApiClient _apiClient;
  final SyncQueue _syncQueue;
  final SupabaseRealtimeService _realtimeService;

  StreamSubscription? _eventUpdateSubscription;
  StreamSubscription? _connectionStateSubscription;

  CalendarNotifier({
    required FamQuestStorage localStorage,
    required ApiClient apiClient,
    required SyncQueue syncQueue,
    required SupabaseRealtimeService realtimeService,
  })  : _localStorage = localStorage,
        _apiClient = apiClient,
        _syncQueue = syncQueue,
        _realtimeService = realtimeService,
        super(CalendarState(focusedDate: DateTime.now()));

  /// Initialize with real-time subscriptions
  Future<void> initialize() async {
    // Listen to real-time event updates
    _eventUpdateSubscription = _realtimeService.eventUpdateStream.listen(
      (update) => _handleRealtimeUpdate(update),
    );

    // Listen to connection state changes
    _connectionStateSubscription = _realtimeService.connectionStateStream.listen(
      (connectionState) {
        state = state.copyWith(
          isRealtimeConnected: connectionState == RealtimeConnectionState.connected,
        );
      },
    );
  }

  /// Handle real-time updates
  void _handleRealtimeUpdate(Map<String, dynamic> update) {
    final type = update['type'] as String;
    final data = update['data'] as Map<String, dynamic>;

    switch (type) {
      case 'insert':
        _handleEventInsert(data);
        break;
      case 'update':
        _handleEventUpdate(data);
        break;
      case 'delete':
        _handleEventDelete(data);
        break;
    }
  }

  /// Handle event insert from real-time
  void _handleEventInsert(Map<String, dynamic> data) {
    try {
      final event = CalendarEvent.fromJson(data);

      // Check if event already exists (avoid duplicates)
      if (state.events.any((e) => e.id == event.id)) {
        return;
      }

      // Add to state
      state = state.copyWith(
        events: [...state.events, event],
      );
    } catch (e) {
      AppLogger.debug('[CalendarProvider] Insert error: $e');
    }
  }

  /// Handle event update from real-time
  void _handleEventUpdate(Map<String, dynamic> data) {
    try {
      final updatedEvent = CalendarEvent.fromJson(data);

      // Update in state
      final updatedEvents = state.events.map((event) {
        return event.id == updatedEvent.id ? updatedEvent : event;
      }).toList();

      state = state.copyWith(events: updatedEvents);
    } catch (e) {
      AppLogger.debug('[CalendarProvider] Update error: $e');
    }
  }

  /// Handle event delete from real-time
  void _handleEventDelete(Map<String, dynamic> data) {
    try {
      final eventId = data['id'] as String;

      // Remove from state
      final updatedEvents = state.events.where((event) => event.id != eventId).toList();

      state = state.copyWith(events: updatedEvents);
    } catch (e) {
      AppLogger.debug('[CalendarProvider] Delete error: $e');
    }
  }

  /// Fetch events for date range
  Future<void> fetchEvents(DateTime start, DateTime end) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load from local storage first (offline-first)
      final localEvents = await _localStorage.query(
        'events',
        where: (event) {
          final eventStart = DateTime.parse(event['startTime'] as String);
          final eventEnd = DateTime.parse(event['endTime'] as String);
          return (eventStart.isBefore(end) && eventEnd.isAfter(start)) ||
              (eventStart.isAfter(start) && eventStart.isBefore(end));
        },
      );

      final events = localEvents.map((e) => CalendarEvent.fromJson(e)).toList();
      state = state.copyWith(events: events, isLoading: false);

      // Trigger background sync
      _syncQueue.scheduleSyncIfNeeded();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load events: $e',
      );
    }
  }

  /// Create new event (optimistic UI)
  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    try {
      // Generate ID if not present
      final newEvent = CalendarEvent(
        id: event.id.isEmpty ? const Uuid().v4() : event.id,
        familyId: event.familyId,
        title: event.title,
        description: event.description,
        startTime: event.startTime,
        endTime: event.endTime,
        isAllDay: event.isAllDay,
        attendees: event.attendees,
        category: event.category,
        color: event.color,
        location: event.location,
        recurrence: event.recurrence,
        isDirty: true,
        version: 1,
        updatedAt: DateTime.now().toUtc(),
        lastModifiedBy: event.lastModifiedBy,
      );

      // Save to local storage immediately
      await _localStorage.put('events', newEvent.id, newEvent.toJson());

      // Queue for sync
      await _syncQueue.enqueue(SyncOperation(
        entityType: 'event',
        operation: 'create',
        entityId: newEvent.id,
        data: newEvent.toJson(),
      ));

      // Update state
      final updatedEvents = [...state.events, newEvent];
      state = state.copyWith(events: updatedEvents);

      // Trigger background sync
      _syncQueue.scheduleSyncIfNeeded();

      return newEvent;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create event: $e');
      rethrow;
    }
  }

  /// Update event (optimistic UI)
  Future<void> updateEvent(String id, CalendarEvent updatedEvent) async {
    try {
      // Update local storage
      await _localStorage.put('events', id, updatedEvent.toJson());

      // Queue for sync
      await _syncQueue.enqueue(SyncOperation(
        entityType: 'event',
        operation: 'update',
        entityId: id,
        data: updatedEvent.toJson(),
      ));

      // Update state
      final updatedEvents = state.events.map((e) {
        return e.id == id ? updatedEvent : e;
      }).toList();
      state = state.copyWith(events: updatedEvents);

      // Trigger background sync
      _syncQueue.scheduleSyncIfNeeded();
    } catch (e) {
      state = state.copyWith(error: 'Failed to update event: $e');
      rethrow;
    }
  }

  /// Delete event (optimistic UI)
  Future<void> deleteEvent(String id) async {
    try {
      // Soft delete in local storage
      await _localStorage.delete('events', id);

      // Queue for sync
      await _syncQueue.enqueue(SyncOperation(
        entityType: 'event',
        operation: 'delete',
        entityId: id,
        data: {'id': id, 'isDeleted': true},
      ));

      // Update state
      final updatedEvents = state.events.where((e) => e.id != id).toList();
      state = state.copyWith(events: updatedEvents);

      // Trigger background sync
      _syncQueue.scheduleSyncIfNeeded();
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete event: $e');
      rethrow;
    }
  }

  /// Get events for specific date
  List<CalendarEvent> getEventsForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return state.events.where((event) {
      final eventStart =
          DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
      final eventEnd =
          DateTime(event.endTime.year, event.endTime.month, event.endTime.day);
      return (eventStart.isAtSameMomentAs(dateOnly) ||
          eventEnd.isAtSameMomentAs(dateOnly) ||
          (eventStart.isBefore(dateOnly) && eventEnd.isAfter(dateOnly)));
    }).toList();
  }

  /// Get events for week
  List<CalendarEvent> getEventsForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return state.events.where((event) {
      return event.startTime.isBefore(weekEnd) &&
          event.endTime.isAfter(weekStart);
    }).toList();
  }

  /// Set focused date
  void setFocusedDate(DateTime date) {
    state = state.copyWith(focusedDate: date);
  }

  @override
  void dispose() {
    _eventUpdateSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    super.dispose();
  }
}

/// Provider instances
final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  return CalendarNotifier(
    localStorage: FamQuestStorage.instance,
    apiClient: ApiClient.instance,
    syncQueue: SyncQueue.instance,
    realtimeService: SupabaseRealtimeService.instance,
  );
});
