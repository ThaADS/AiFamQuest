/// Kiosk mode data models for shared family device displays
///
/// These models support the kiosk feature where a tablet/smart display
/// shows family tasks and events in read-only fullscreen mode.

import 'package:intl/intl.dart';

/// A task displayed in kiosk mode (simplified view)
class KioskTask {
  final String id;
  final String title;
  final bool completed;
  final int? pointValue;
  final DateTime? dueDate;

  KioskTask({
    required this.id,
    required this.title,
    required this.completed,
    this.pointValue,
    this.dueDate,
  });

  factory KioskTask.fromJson(Map<String, dynamic> json) {
    return KioskTask(
      id: json['id'] as String,
      title: json['title'] as String,
      completed: json['completed'] as bool? ?? false,
      pointValue: json['pointValue'] as int?,
      dueDate: json['dueDate'] != null
        ? DateTime.parse(json['dueDate'] as String)
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
      'pointValue': pointValue,
      'dueDate': dueDate?.toIso8601String(),
    };
  }
}

/// A family member displayed in kiosk mode with their tasks
class KioskMember {
  final String id;
  final String displayName;
  final String avatar;
  final List<KioskTask> tasks;
  final int totalPoints;
  final int weeklyPoints;

  KioskMember({
    required this.id,
    required this.displayName,
    required this.avatar,
    required this.tasks,
    this.totalPoints = 0,
    this.weeklyPoints = 0,
  });

  factory KioskMember.fromJson(Map<String, dynamic> json) {
    return KioskMember(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      avatar: json['avatar'] as String? ?? '',
      tasks: (json['tasks'] as List<dynamic>?)
        ?.map((t) => KioskTask.fromJson(t as Map<String, dynamic>))
        .toList() ?? [],
      totalPoints: json['totalPoints'] as int? ?? 0,
      weeklyPoints: json['weeklyPoints'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'avatar': avatar,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'totalPoints': totalPoints,
      'weeklyPoints': weeklyPoints,
    };
  }

  /// Calculate task completion percentage (0.0 to 1.0)
  double get completionRate {
    if (tasks.isEmpty) return 0.0;
    final completed = tasks.where((t) => t.completed).length;
    return completed / tasks.length;
  }

  /// Get count of completed tasks
  int get completedCount => tasks.where((t) => t.completed).length;

  /// Get count of total tasks
  int get totalTaskCount => tasks.length;
}

/// A calendar event displayed in kiosk mode
class KioskEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? description;
  final String? location;
  final String color;
  final List<String> memberIds;

  KioskEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.description,
    this.location,
    this.color = '#2196F3',
    this.memberIds = const [],
  });

  factory KioskEvent.fromJson(Map<String, dynamic> json) {
    return KioskEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      description: json['description'] as String?,
      location: json['location'] as String?,
      color: json['color'] as String? ?? '#2196F3',
      memberIds: (json['memberIds'] as List<dynamic>?)
        ?.map((id) => id.toString())
        .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'description': description,
      'location': location,
      'color': color,
      'memberIds': memberIds,
    };
  }

  /// Format event time range for display (e.g., "3:00 PM - 4:30 PM")
  String get timeRange {
    final formatter = DateFormat('h:mm a');
    return '${formatter.format(start)} - ${formatter.format(end)}';
  }

  /// Get event duration in minutes
  int get durationMinutes {
    return end.difference(start).inMinutes;
  }

  /// Check if event is currently happening
  bool get isHappening {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }
}

/// Data for kiosk "today" view
class KioskTodayData {
  final List<KioskMember> members;
  final List<KioskEvent> events;
  final DateTime date;
  final String? familyName;

  KioskTodayData({
    required this.members,
    required this.events,
    required this.date,
    this.familyName,
  });

  factory KioskTodayData.fromJson(Map<String, dynamic> json) {
    return KioskTodayData(
      members: (json['members'] as List<dynamic>?)
        ?.map((m) => KioskMember.fromJson(m as Map<String, dynamic>))
        .toList() ?? [],
      events: (json['events'] as List<dynamic>?)
        ?.map((e) => KioskEvent.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
      date: json['date'] != null
        ? DateTime.parse(json['date'] as String)
        : DateTime.now(),
      familyName: json['familyName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'members': members.map((m) => m.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      'date': date.toIso8601String(),
      'familyName': familyName,
    };
  }

  /// Get total family task completion rate
  double get familyCompletionRate {
    if (members.isEmpty) return 0.0;
    final totalTasks = members.fold(0, (sum, m) => sum + m.totalTaskCount);
    if (totalTasks == 0) return 0.0;
    final completedTasks = members.fold(0, (sum, m) => sum + m.completedCount);
    return completedTasks / totalTasks;
  }

  /// Get upcoming events (future events today)
  List<KioskEvent> get upcomingEvents {
    final now = DateTime.now();
    return events
      .where((e) => e.start.isAfter(now))
      .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Get current/ongoing events
  List<KioskEvent> get currentEvents {
    return events.where((e) => e.isHappening).toList();
  }
}

/// Data for a single day in week view
class KioskDayData {
  final DateTime date;
  final List<KioskEvent> events;
  final int tasksTotal;
  final int tasksCompleted;

  KioskDayData({
    required this.date,
    required this.events,
    required this.tasksTotal,
    required this.tasksCompleted,
  });

  factory KioskDayData.fromJson(Map<String, dynamic> json) {
    return KioskDayData(
      date: DateTime.parse(json['date'] as String),
      events: (json['events'] as List<dynamic>?)
        ?.map((e) => KioskEvent.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
      tasksTotal: json['tasksTotal'] as int? ?? 0,
      tasksCompleted: json['tasksCompleted'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'events': events.map((e) => e.toJson()).toList(),
      'tasksTotal': tasksTotal,
      'tasksCompleted': tasksCompleted,
    };
  }

  /// Get day completion rate
  double get completionRate {
    if (tasksTotal == 0) return 0.0;
    return tasksCompleted / tasksTotal;
  }

  /// Check if this is today
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  /// Get day name (e.g., "Mon", "Tue")
  String get dayName => DateFormat('EEE').format(date);

  /// Get day number (e.g., "15")
  String get dayNumber => DateFormat('d').format(date);
}

/// Data for kiosk "week" view
class KioskWeekData {
  final List<KioskDayData> days;
  final DateTime startDate;
  final DateTime endDate;
  final String? familyName;

  KioskWeekData({
    required this.days,
    required this.startDate,
    required this.endDate,
    this.familyName,
  });

  factory KioskWeekData.fromJson(Map<String, dynamic> json) {
    return KioskWeekData(
      days: (json['days'] as List<dynamic>?)
        ?.map((d) => KioskDayData.fromJson(d as Map<String, dynamic>))
        .toList() ?? [],
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      familyName: json['familyName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'days': days.map((d) => d.toJson()).toList(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'familyName': familyName,
    };
  }

  /// Get week completion rate
  double get weekCompletionRate {
    if (days.isEmpty) return 0.0;
    final totalTasks = days.fold(0, (sum, d) => sum + d.tasksTotal);
    if (totalTasks == 0) return 0.0;
    final completedTasks = days.fold(0, (sum, d) => sum + d.tasksCompleted);
    return completedTasks / totalTasks;
  }

  /// Get week date range string (e.g., "Nov 11 - Nov 17")
  String get weekRange {
    final formatter = DateFormat('MMM d');
    return '${formatter.format(startDate)} - ${formatter.format(endDate)}';
  }
}
