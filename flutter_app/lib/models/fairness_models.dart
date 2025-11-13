/// Fairness engine data models for workload distribution and capacity tracking
///
/// Provides strongly-typed models for:
/// - Family fairness data and scoring
/// - Individual user workload tracking
/// - Task distribution metrics
/// - Date range filtering

/// Represents overall fairness data for a family
class FairnessData {
  final double fairnessScore; // 0.0-1.0
  final Map<String, UserWorkload> workloads;
  final Map<String, int> taskDistribution;
  final DateTime startDate;
  final DateTime endDate;

  FairnessData({
    required this.fairnessScore,
    required this.workloads,
    required this.taskDistribution,
    required this.startDate,
    required this.endDate,
  });

  factory FairnessData.fromJson(Map<String, dynamic> json) {
    return FairnessData(
      fairnessScore: (json['fairness_score'] ?? 0.0).toDouble(),
      workloads: (json['workloads'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, UserWorkload.fromJson(value as Map<String, dynamic>)),
      ),
      taskDistribution: (json['task_distribution'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, value as int),
      ),
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['end_date'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fairness_score': fairnessScore,
      'workloads': workloads.map((key, value) => MapEntry(key, value.toJson())),
      'task_distribution': taskDistribution,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    };
  }

  /// Get fairness status as a category
  FairnessStatus get status {
    if (fairnessScore >= 0.9) return FairnessStatus.excellent;
    if (fairnessScore >= 0.8) return FairnessStatus.good;
    if (fairnessScore >= 0.7) return FairnessStatus.fair;
    return FairnessStatus.unbalanced;
  }

  /// Get sorted list of workloads (highest percentage first)
  List<UserWorkload> get sortedWorkloads {
    final list = workloads.values.toList();
    list.sort((a, b) => b.percentage.compareTo(a.percentage));
    return list;
  }
}

/// Represents individual user workload and capacity
class UserWorkload {
  final String userId;
  final double usedHours;
  final double totalCapacity;
  final int tasksCompleted;
  final double percentage;
  final String? userName;
  final String? userAvatar;

  UserWorkload({
    required this.userId,
    required this.usedHours,
    required this.totalCapacity,
    required this.tasksCompleted,
    required this.percentage,
    this.userName,
    this.userAvatar,
  });

  factory UserWorkload.fromJson(Map<String, dynamic> json) {
    return UserWorkload(
      userId: json['user_id'] ?? '',
      usedHours: (json['used_hours'] ?? 0.0).toDouble(),
      totalCapacity: (json['total_capacity'] ?? 1.0).toDouble(),
      tasksCompleted: json['tasks_completed'] ?? 0,
      percentage: (json['percentage'] ?? 0.0).toDouble(),
      userName: json['user_name'],
      userAvatar: json['user_avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'used_hours': usedHours,
      'total_capacity': totalCapacity,
      'tasks_completed': tasksCompleted,
      'percentage': percentage,
      'user_name': userName,
      'user_avatar': userAvatar,
    };
  }

  /// Get capacity status as a category
  CapacityStatus get status {
    if (percentage > 100) return CapacityStatus.overloaded;
    if (percentage >= 80) return CapacityStatus.high;
    if (percentage >= 50) return CapacityStatus.moderate;
    return CapacityStatus.light;
  }
}

/// Fairness score categories
enum FairnessStatus {
  excellent,  // >= 90%
  good,       // 80-89%
  fair,       // 70-79%
  unbalanced, // < 70%
}

/// User capacity status categories
enum CapacityStatus {
  light,      // < 50%
  moderate,   // 50-79%
  high,       // 80-100%
  overloaded, // > 100%
}

/// Date range filter options
enum DateRange {
  thisWeek,
  thisMonth,
  allTime,
}

extension DateRangeExtension on DateRange {
  String get label {
    switch (this) {
      case DateRange.thisWeek:
        return 'This Week';
      case DateRange.thisMonth:
        return 'This Month';
      case DateRange.allTime:
        return 'All Time';
    }
  }

  String get apiValue {
    switch (this) {
      case DateRange.thisWeek:
        return 'this_week';
      case DateRange.thisMonth:
        return 'this_month';
      case DateRange.allTime:
        return 'all_time';
    }
  }
}
