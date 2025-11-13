/// Recurring task models for FamQuest
///
/// Provides strongly-typed models for:
/// - Recurring task series (RRULE patterns)
/// - Individual occurrences (instances of recurring tasks)
/// - Rotation strategies (round-robin, fairness, random, manual)

import 'package:flutter/material.dart';

/// Rotation strategy for assigning recurring tasks
enum RotationStrategy {
  roundRobin('round_robin', 'Round Robin', 'Fair turns for everyone'),
  fairness('fairness', 'Fairness', 'Based on capacity and workload'),
  random('random', 'Random', 'Random assignment'),
  manual('manual', 'Manual', 'No auto-assignment');

  final String value;
  final String displayName;
  final String description;

  const RotationStrategy(this.value, this.displayName, this.description);

  static RotationStrategy fromString(String value) {
    return RotationStrategy.values.firstWhere(
      (s) => s.value == value,
      orElse: () => RotationStrategy.roundRobin,
    );
  }

  IconData get icon {
    switch (this) {
      case RotationStrategy.roundRobin:
        return Icons.rotate_right;
      case RotationStrategy.fairness:
        return Icons.balance;
      case RotationStrategy.random:
        return Icons.shuffle;
      case RotationStrategy.manual:
        return Icons.pan_tool;
    }
  }
}

/// Task category
enum TaskCategory {
  cleaning('cleaning', 'Cleaning', Icons.cleaning_services, Colors.blue),
  care('care', 'Care', Icons.favorite, Colors.pink),
  pet('pet', 'Pet Care', Icons.pets, Colors.brown),
  homework('homework', 'Homework', Icons.school, Colors.purple),
  other('other', 'Other', Icons.task, Colors.grey);

  final String value;
  final String displayName;
  final IconData icon;
  final Color color;

  const TaskCategory(this.value, this.displayName, this.icon, this.color);

  static TaskCategory fromString(String value) {
    return TaskCategory.values.firstWhere(
      (c) => c.value == value,
      orElse: () => TaskCategory.other,
    );
  }
}

/// Recurrence frequency
enum RecurrenceFrequency {
  daily('DAILY', 'Daily'),
  weekly('WEEKLY', 'Weekly'),
  monthly('MONTHLY', 'Monthly');

  final String value;
  final String displayName;

  const RecurrenceFrequency(this.value, this.displayName);

  static RecurrenceFrequency fromString(String value) {
    return RecurrenceFrequency.values.firstWhere(
      (f) => f.value == value,
      orElse: () => RecurrenceFrequency.daily,
    );
  }
}

/// Recurring task series (template for generating occurrences)
class RecurringTask {
  final String id;
  final String title;
  final String? description;
  final TaskCategory category;
  final String rrule; // RFC 5545 RRULE string
  final RotationStrategy rotationStrategy;
  final List<String> assigneeIds;
  final int points;
  final int estimatedMinutes;
  final bool photoRequired;
  final bool parentApproval;
  final bool isPaused;
  final DateTime createdAt;
  final String createdBy;

  RecurringTask({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.rrule,
    required this.rotationStrategy,
    required this.assigneeIds,
    required this.points,
    required this.estimatedMinutes,
    this.photoRequired = false,
    this.parentApproval = false,
    this.isPaused = false,
    required this.createdAt,
    required this.createdBy,
  });

  factory RecurringTask.fromJson(Map<String, dynamic> json) {
    return RecurringTask(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      category: TaskCategory.fromString(json['category'] ?? 'other'),
      rrule: json['rrule'] ?? '',
      rotationStrategy: RotationStrategy.fromString(
          json['rotation_strategy'] ?? json['rotationStrategy'] ?? 'round_robin'),
      assigneeIds: json['assignee_ids'] != null
          ? List<String>.from(json['assignee_ids'])
          : json['assigneeIds'] != null
              ? List<String>.from(json['assigneeIds'])
              : [],
      points: json['points'] ?? 10,
      estimatedMinutes: json['estimated_minutes'] ?? json['estimatedMinutes'] ?? 15,
      photoRequired: json['photo_required'] ?? json['photoRequired'] ?? false,
      parentApproval: json['parent_approval'] ?? json['parentApproval'] ?? false,
      isPaused: json['is_paused'] ?? json['isPaused'] ?? false,
      createdAt: json['created_at'] != null || json['createdAt'] != null
          ? DateTime.parse(json['created_at'] ?? json['createdAt'])
          : DateTime.now(),
      createdBy: json['created_by'] ?? json['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.value,
      'rrule': rrule,
      'rotation_strategy': rotationStrategy.value,
      'assignee_ids': assigneeIds,
      'points': points,
      'estimated_minutes': estimatedMinutes,
      'photo_required': photoRequired,
      'parent_approval': parentApproval,
      'is_paused': isPaused,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  /// Get human-readable recurrence pattern
  String get humanReadablePattern {
    // Parse RRULE to human-readable format
    if (rrule.contains('FREQ=DAILY')) {
      final interval = _extractInterval();
      return interval > 1 ? 'Every $interval days' : 'Daily';
    } else if (rrule.contains('FREQ=WEEKLY')) {
      final days = _extractByDay();
      final interval = _extractInterval();
      final prefix = interval > 1 ? 'Every $interval weeks on' : 'Weekly on';
      return '$prefix ${days.join(", ")}';
    } else if (rrule.contains('FREQ=MONTHLY')) {
      final day = _extractByMonthDay();
      final interval = _extractInterval();
      final prefix = interval > 1 ? 'Every $interval months on' : 'Monthly on';
      return '$prefix day $day';
    }
    return 'Custom pattern';
  }

  int _extractInterval() {
    final match = RegExp(r'INTERVAL=(\d+)').firstMatch(rrule);
    return match != null ? int.parse(match.group(1)!) : 1;
  }

  List<String> _extractByDay() {
    final match = RegExp(r'BYDAY=([A-Z,]+)').firstMatch(rrule);
    if (match == null) return [];
    final days = match.group(1)!.split(',');
    return days.map((d) => _dayCodeToName(d)).toList();
  }

  String _dayCodeToName(String code) {
    const map = {
      'MO': 'Mon',
      'TU': 'Tue',
      'WE': 'Wed',
      'TH': 'Thu',
      'FR': 'Fri',
      'SA': 'Sat',
      'SU': 'Sun',
    };
    return map[code] ?? code;
  }

  int _extractByMonthDay() {
    final match = RegExp(r'BYMONTHDAY=(\d+)').firstMatch(rrule);
    return match != null ? int.parse(match.group(1)!) : 1;
  }
}

/// Task occurrence status
enum OccurrenceStatus {
  open('open', 'Open', Colors.blue),
  done('done', 'Done', Colors.green),
  overdue('overdue', 'Overdue', Colors.red),
  pendingApproval('pending_approval', 'Pending Approval', Colors.orange),
  skipped('skipped', 'Skipped', Colors.grey);

  final String value;
  final String displayName;
  final Color color;

  const OccurrenceStatus(this.value, this.displayName, this.color);

  static OccurrenceStatus fromString(String value) {
    return OccurrenceStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => OccurrenceStatus.open,
    );
  }
}

/// Individual occurrence of a recurring task
class Occurrence {
  final String id;
  final String recurringTaskId;
  final String title;
  final String? description;
  final TaskCategory category;
  final DateTime scheduledAt;
  final String? assignedTo;
  final String? assignedToName;
  final OccurrenceStatus status;
  final int points;
  final int? earnedPoints;
  final DateTime? completedAt;
  final String? completedBy;
  final List<String> proofPhotos;
  final String? completionNote;
  final int? qualityRating;

  Occurrence({
    required this.id,
    required this.recurringTaskId,
    required this.title,
    this.description,
    required this.category,
    required this.scheduledAt,
    this.assignedTo,
    this.assignedToName,
    required this.status,
    required this.points,
    this.earnedPoints,
    this.completedAt,
    this.completedBy,
    this.proofPhotos = const [],
    this.completionNote,
    this.qualityRating,
  });

  factory Occurrence.fromJson(Map<String, dynamic> json) {
    return Occurrence(
      id: json['id'] ?? '',
      recurringTaskId: json['recurring_task_id'] ?? json['recurringTaskId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      category: TaskCategory.fromString(json['category'] ?? 'other'),
      scheduledAt: json['scheduled_at'] != null || json['scheduledAt'] != null
          ? DateTime.parse(json['scheduled_at'] ?? json['scheduledAt'])
          : DateTime.now(),
      assignedTo: json['assigned_to'] ?? json['assignedTo'],
      assignedToName: json['assigned_to_name'] ?? json['assignedToName'],
      status: OccurrenceStatus.fromString(json['status'] ?? 'open'),
      points: json['points'] ?? 0,
      earnedPoints: json['earned_points'] ?? json['earnedPoints'],
      completedAt: json['completed_at'] != null || json['completedAt'] != null
          ? DateTime.parse(json['completed_at'] ?? json['completedAt'])
          : null,
      completedBy: json['completed_by'] ?? json['completedBy'],
      proofPhotos: json['proof_photos'] != null
          ? List<String>.from(json['proof_photos'])
          : json['proofPhotos'] != null
              ? List<String>.from(json['proofPhotos'])
              : [],
      completionNote: json['completion_note'] ?? json['completionNote'],
      qualityRating: json['quality_rating'] ?? json['qualityRating'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recurring_task_id': recurringTaskId,
      'title': title,
      'description': description,
      'category': category.value,
      'scheduled_at': scheduledAt.toIso8601String(),
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
      'status': status.value,
      'points': points,
      'earned_points': earnedPoints,
      'completed_at': completedAt?.toIso8601String(),
      'completed_by': completedBy,
      'proof_photos': proofPhotos,
      'completion_note': completionNote,
      'quality_rating': qualityRating,
    };
  }

  bool get isOpen => status == OccurrenceStatus.open;
  bool get isDone => status == OccurrenceStatus.done;
  bool get isOverdue => status == OccurrenceStatus.overdue;
  bool get isPendingApproval => status == OccurrenceStatus.pendingApproval;
  bool get isSkipped => status == OccurrenceStatus.skipped;
}

/// Preview of next occurrences with assignments
class OccurrencePreview {
  final DateTime date;
  final String assignedTo;
  final String assignedToName;

  OccurrencePreview({
    required this.date,
    required this.assignedTo,
    required this.assignedToName,
  });

  factory OccurrencePreview.fromJson(Map<String, dynamic> json) {
    return OccurrencePreview(
      date: DateTime.parse(json['date']),
      assignedTo: json['assigned_to'] ?? json['assignedTo'] ?? '',
      assignedToName: json['assigned_to_name'] ?? json['assignedToName'] ?? 'Unassigned',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
    };
  }
}
