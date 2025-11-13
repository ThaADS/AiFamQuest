/// Gamification data models for FamQuest
///
/// Provides strongly-typed models for:
/// - User streaks (current, longest, at-risk status)
/// - Badges (earned and progress toward unlocking)
/// - Points (balance, history, transactions)
/// - Leaderboard (family rankings)
/// - User stats (comprehensive dashboard data)

import 'package:flutter/material.dart';

/// User streak information
class UserStreak {
  final String userId;
  final int current;
  final int longest;
  final int daysSinceLast;
  final bool isAtRisk;
  final DateTime? lastCompletionDate;

  UserStreak({
    required this.userId,
    required this.current,
    required this.longest,
    this.daysSinceLast = 0,
    this.isAtRisk = false,
    this.lastCompletionDate,
  });

  factory UserStreak.fromJson(Map<String, dynamic> json) {
    return UserStreak(
      userId: json['user_id'] ?? json['userId'] ?? '',
      current: json['current'] ?? 0,
      longest: json['longest'] ?? 0,
      daysSinceLast: json['days_since_last'] ?? json['daysSinceLast'] ?? 0,
      isAtRisk: json['is_at_risk'] ?? json['isAtRisk'] ?? false,
      lastCompletionDate: json['last_completion_date'] != null ||
              json['lastCompletionDate'] != null
          ? DateTime.parse(
              json['last_completion_date'] ?? json['lastCompletionDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'current': current,
      'longest': longest,
      'days_since_last': daysSinceLast,
      'is_at_risk': isAtRisk,
      'last_completion_date': lastCompletionDate?.toIso8601String(),
    };
  }
}

/// Badge definition with unlock criteria
class BadgeDefinition {
  final String code;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const BadgeDefinition({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  /// Get badge icon for code
  static IconData getIconForCode(String code) {
    if (code.startsWith('streak_')) return Icons.local_fire_department;
    if (code.startsWith('points_')) return Icons.star;
    if (code.startsWith('tasks_')) return Icons.task_alt;
    if (code.startsWith('category_master_')) return Icons.workspace_premium;
    if (code == 'first_task') return Icons.check_circle;
    if (code == 'early_bird') return Icons.wb_sunny;
    if (code == 'night_owl') return Icons.nightlight;
    return Icons.emoji_events;
  }

  /// Get badge color for code
  static Color getColorForCode(String code) {
    if (code.startsWith('streak_')) return Colors.orange;
    if (code.startsWith('points_')) return Colors.amber;
    if (code.startsWith('tasks_')) return Colors.green;
    if (code.startsWith('category_master_')) return Colors.purple;
    if (code == 'first_task') return Colors.blue;
    if (code == 'early_bird') return Colors.yellow;
    if (code == 'night_owl') return Colors.indigo;
    return Colors.grey;
  }
}

/// User badge (earned)
class UserBadge {
  final String id;
  final String userId;
  final String code;
  final String name;
  final String description;
  final DateTime awardedAt;

  UserBadge({
    required this.id,
    required this.userId,
    required this.code,
    required this.name,
    required this.description,
    required this.awardedAt,
  });

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      awardedAt: json['awarded_at'] != null || json['awardedAt'] != null
          ? DateTime.parse(json['awarded_at'] ?? json['awardedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'code': code,
      'name': name,
      'description': description,
      'awarded_at': awardedAt.toIso8601String(),
    };
  }

  IconData get icon => BadgeDefinition.getIconForCode(code);
  Color get color => BadgeDefinition.getColorForCode(code);
}

/// Badge progress (toward unlocking)
class BadgeProgress {
  final String code;
  final String name;
  final String description;
  final int current;
  final int target;
  final bool isEarned;

  BadgeProgress({
    required this.code,
    required this.name,
    required this.description,
    required this.current,
    required this.target,
    this.isEarned = false,
  });

  factory BadgeProgress.fromJson(Map<String, dynamic> json) {
    return BadgeProgress(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      current: json['current'] ?? 0,
      target: json['target'] ?? 1,
      isEarned: json['is_earned'] ?? json['isEarned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'description': description,
      'current': current,
      'target': target,
      'is_earned': isEarned,
    };
  }

  double get progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
  IconData get icon => BadgeDefinition.getIconForCode(code);
  Color get color => BadgeDefinition.getColorForCode(code);
}

/// Points transaction history entry
class PointsTransaction {
  final String id;
  final String userId;
  final int amount;
  final String type; // 'earned' or 'spent'
  final String? reason;
  final String? taskId;
  final String? rewardId;
  final DateTime timestamp;
  final int runningBalance;

  PointsTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    this.reason,
    this.taskId,
    this.rewardId,
    required this.timestamp,
    this.runningBalance = 0,
  });

  factory PointsTransaction.fromJson(Map<String, dynamic> json) {
    return PointsTransaction(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      amount: json['amount'] ?? 0,
      type: json['type'] ?? 'earned',
      reason: json['reason'],
      taskId: json['task_id'] ?? json['taskId'],
      rewardId: json['reward_id'] ?? json['rewardId'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      runningBalance: json['running_balance'] ?? json['runningBalance'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'type': type,
      'reason': reason,
      'task_id': taskId,
      'reward_id': rewardId,
      'timestamp': timestamp.toIso8601String(),
      'running_balance': runningBalance,
    };
  }

  bool get isEarned => type == 'earned';
  bool get isSpent => type == 'spent';
}

/// Leaderboard entry
class LeaderboardEntry {
  final int rank;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int points;
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.points,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] ?? 0,
      userId: json['user_id'] ?? json['userId'] ?? '',
      displayName: json['display_name'] ?? json['displayName'] ?? 'User',
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      points: json['points'] ?? 0,
      isCurrentUser: json['is_current_user'] ?? json['isCurrentUser'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'user_id': userId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'points': points,
      'is_current_user': isCurrentUser,
    };
  }

  String get rankEmoji {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }
}

/// Comprehensive user stats
class UserStats {
  final String userId;
  final int points;
  final int tasksCompleted;
  final int tasksThisWeek;
  final UserStreak streak;
  final int badgesEarned;
  final int familyRank;

  UserStats({
    required this.userId,
    required this.points,
    required this.tasksCompleted,
    required this.tasksThisWeek,
    required this.streak,
    required this.badgesEarned,
    this.familyRank = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      userId: json['user_id'] ?? json['userId'] ?? '',
      points: json['points'] ?? 0,
      tasksCompleted: json['tasks_completed'] ?? json['tasksCompleted'] ?? 0,
      tasksThisWeek: json['tasks_this_week'] ?? json['tasksThisWeek'] ?? 0,
      streak: json['streak'] != null
          ? UserStreak.fromJson(json['streak'])
          : UserStreak(userId: '', current: 0, longest: 0),
      badgesEarned: json['badges_earned'] ?? json['badgesEarned'] ?? 0,
      familyRank: json['family_rank'] ?? json['familyRank'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'points': points,
      'tasks_completed': tasksCompleted,
      'tasks_this_week': tasksThisWeek,
      'streak': streak.toJson(),
      'badges_earned': badgesEarned,
      'family_rank': familyRank,
    };
  }
}

/// Task completion preview (before completing)
class TaskRewardPreview {
  final int estimatedPoints;
  final int basePoints;
  final int streakBonus;
  final List<BadgeProgress> potentialBadges;
  final int currentStreak;

  TaskRewardPreview({
    required this.estimatedPoints,
    required this.basePoints,
    this.streakBonus = 0,
    this.potentialBadges = const [],
    this.currentStreak = 0,
  });

  factory TaskRewardPreview.fromJson(Map<String, dynamic> json) {
    return TaskRewardPreview(
      estimatedPoints: json['estimated_points'] ?? json['estimatedPoints'] ?? 0,
      basePoints: json['base_points'] ?? json['basePoints'] ?? 0,
      streakBonus: json['streak_bonus'] ?? json['streakBonus'] ?? 0,
      potentialBadges: json['potential_badges'] != null
          ? (json['potential_badges'] as List)
              .map((b) => BadgeProgress.fromJson(b))
              .toList()
          : [],
      currentStreak: json['current_streak'] ?? json['currentStreak'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'estimated_points': estimatedPoints,
      'base_points': basePoints,
      'streak_bonus': streakBonus,
      'potential_badges': potentialBadges.map((b) => b.toJson()).toList(),
      'current_streak': currentStreak,
    };
  }

  bool get hasStreakBonus => streakBonus > 0;
  bool get hasPotentialBadges => potentialBadges.isNotEmpty;
}

/// Complete gamification profile
class GamificationProfile {
  final String userId;
  final int points;
  final UserStreak streak;
  final List<UserBadge> badges;
  final int familyRank;
  final List<dynamic> affordableRewards;

  GamificationProfile({
    required this.userId,
    required this.points,
    required this.streak,
    required this.badges,
    this.familyRank = 0,
    this.affordableRewards = const [],
  });

  factory GamificationProfile.fromJson(Map<String, dynamic> json) {
    return GamificationProfile(
      userId: json['user_id'] ?? json['userId'] ?? '',
      points: json['points'] ?? 0,
      streak: json['streak'] != null
          ? UserStreak.fromJson(json['streak'])
          : UserStreak(userId: '', current: 0, longest: 0),
      badges: json['badges'] != null
          ? (json['badges'] as List).map((b) => UserBadge.fromJson(b)).toList()
          : [],
      familyRank: json['family_rank'] ?? json['familyRank'] ?? 0,
      affordableRewards: json['affordable_rewards'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'points': points,
      'streak': streak.toJson(),
      'badges': badges.map((b) => b.toJson()).toList(),
      'family_rank': familyRank,
      'affordable_rewards': affordableRewards,
    };
  }
}
