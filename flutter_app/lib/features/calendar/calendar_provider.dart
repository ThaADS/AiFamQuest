import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/local_storage.dart';
import '../../api/client.dart';
import '../../services/sync_queue.dart';
import 'package:uuid/uuid.dart';

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
    RecurrenceRule? recurrence,
    bool clearRecurrence = false,
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

  CalendarState({
    this.events = const [],
    this.isLoading = false,
    this.error,
    required this.focusedDate,
  });

  CalendarState copyWith({
    List<CalendarEvent>? events,
    bool? isLoading,
    String? error,
    DateTime? focusedDate,
  }) {
    return CalendarState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      focusedDate: focusedDate ?? this.focusedDate,
    );
  }
}

/// Calendar provider
class CalendarNotifier extends StateNotifier<CalendarState> {
  final LocalStorage _localStorage;
  // ignore: unused_field
  final ApiClient _apiClient;
  final SyncQueue _syncQueue;

  CalendarNotifier({
    required LocalStorage localStorage,
    required ApiClient apiClient,
    required SyncQueue syncQueue,
  })  : _localStorage = localStorage,
        _apiClient = apiClient,
        _syncQueue = syncQueue,
        super(CalendarState(focusedDate: DateTime.now()));

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
}

/// Provider instances
final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  return CalendarNotifier(
    localStorage: LocalStorage.instance,
    apiClient: ApiClient.instance,
    syncQueue: SyncQueue.instance,
  );
});
