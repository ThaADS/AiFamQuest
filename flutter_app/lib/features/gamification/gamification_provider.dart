/// Gamification Provider (Riverpod State Management)
///
/// Manages gamification state:
/// - Current user points (reactive)
/// - Current user streak (reactive)
/// - Badges list (cached)
/// - Leaderboard (cached, refresh on pull)
/// - Auto-refresh on app resume
/// - Update after task completion

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/gamification_models.dart';
import '../../api/gamification_client.dart';

// Providers

/// Current user ID provider (set during login)
final currentUserIdProvider = StateProvider<String?>((ref) => null);

/// Current family ID provider (set during login)
final currentFamilyIdProvider = StateProvider<String?>((ref) => null);

/// Gamification profile provider (reactive)
final gamificationProfileProvider =
    FutureProvider.autoDispose<GamificationProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final client = GamificationClient.instance;

  try {
    final profile = await client.getProfile(userId);

    // Cache for offline access
    final box = await Hive.openBox('gamification_cache');
    await box.put('profile_$userId', profile.toJson());

    return profile;
  } catch (e) {
    // Fallback to cached data
    final box = await Hive.openBox('gamification_cache');
    final cached = box.get('profile_$userId');
    if (cached != null) {
      return GamificationProfile.fromJson(Map<String, dynamic>.from(cached));
    }
    rethrow;
  }
});

/// Points provider (reactive, extracted from profile)
final pointsProvider = Provider.autoDispose<int>((ref) {
  final profile = ref.watch(gamificationProfileProvider);
  return profile.when(
    data: (p) => p?.points ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Streak provider (reactive, extracted from profile)
final streakProvider = Provider.autoDispose<UserStreak?>((ref) {
  final profile = ref.watch(gamificationProfileProvider);
  return profile.when(
    data: (p) => p?.streak,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Badges provider (with caching)
final badgesProvider = FutureProvider.autoDispose<List<UserBadge>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final client = GamificationClient.instance;

  try {
    final data = await client.getAvailableBadges(userId);
    final badges = data['earned'] as List<UserBadge>;

    // Cache for offline access
    final box = await Hive.openBox('gamification_cache');
    await box.put(
      'badges_$userId',
      badges.map((b) => b.toJson()).toList(),
    );

    return badges;
  } catch (e) {
    // Fallback to cached data
    final box = await Hive.openBox('gamification_cache');
    final cached = box.get('badges_$userId');
    if (cached != null) {
      return (cached as List)
          .map((b) => UserBadge.fromJson(Map<String, dynamic>.from(b)))
          .toList();
    }
    rethrow;
  }
});

/// Badge progress provider (for locked badges)
final badgeProgressProvider =
    FutureProvider.autoDispose<List<BadgeProgress>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final client = GamificationClient.instance;

  try {
    final data = await client.getAvailableBadges(userId);
    final progress = data['progress'] as List<BadgeProgress>;

    // Cache for offline access
    final box = await Hive.openBox('gamification_cache');
    await box.put(
      'badge_progress_$userId',
      progress.map((p) => p.toJson()).toList(),
    );

    return progress;
  } catch (e) {
    // Fallback to cached data
    final box = await Hive.openBox('gamification_cache');
    final cached = box.get('badge_progress_$userId');
    if (cached != null) {
      return (cached as List)
          .map((p) => BadgeProgress.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    }
    rethrow;
  }
});

/// Leaderboard provider (with caching)
final leaderboardProvider = FutureProvider.autoDispose
    .family<List<LeaderboardEntry>, String>((ref, period) async {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return [];

  final client = GamificationClient.instance;

  try {
    final entries = await client.getLeaderboard(familyId, period: period);

    // Cache for offline access
    final box = await Hive.openBox('gamification_cache');
    await box.put(
      'leaderboard_${familyId}_$period',
      entries.map((e) => e.toJson()).toList(),
    );

    return entries;
  } catch (e) {
    // Fallback to cached data
    final box = await Hive.openBox('gamification_cache');
    final cached = box.get('leaderboard_${familyId}_$period');
    if (cached != null) {
      return (cached as List)
          .map((e) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    rethrow;
  }
});

/// Streak history provider
final streakHistoryProvider = FutureProvider.autoDispose<StreakHistory?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final client = GamificationClient.instance;

  try {
    final history = await client.getStreakHistory(userId);

    // Cache for offline access
    final box = await Hive.openBox('gamification_cache');
    await box.put('streak_history_$userId', history.toJson());

    return history;
  } catch (e) {
    // Fallback to cached data
    final box = await Hive.openBox('gamification_cache');
    final cached = box.get('streak_history_$userId');
    if (cached != null) {
      return StreakHistory.fromJson(Map<String, dynamic>.from(cached));
    }
    rethrow;
  }
});

/// Gamification notifier for manual updates
class GamificationNotifier extends ChangeNotifier {
  final Ref ref;

  GamificationNotifier(this.ref);

  /// Refresh all gamification data
  Future<void> refreshAll() async {
    ref.invalidate(gamificationProfileProvider);
    ref.invalidate(badgesProvider);
    ref.invalidate(badgeProgressProvider);
    ref.invalidate(leaderboardProvider);
    ref.invalidate(streakHistoryProvider);
    notifyListeners();
  }

  /// Update after task completion
  Future<void> onTaskCompleted() async {
    await refreshAll();
  }

  /// Manual point update (optimistic UI)
  void addPoints(int points) {
    // Invalidate profile to trigger refresh
    ref.invalidate(gamificationProfileProvider);
    notifyListeners();
  }

  /// Manual badge unlock (optimistic UI)
  void unlockBadge(UserBadge badge) {
    // Invalidate badges to trigger refresh
    ref.invalidate(badgesProvider);
    notifyListeners();
  }

  /// Get earned badges for a user
  Future<List<UserBadge>> getBadges(String userId) async {
    final client = GamificationClient.instance;
    final data = await client.getAvailableBadges(userId);
    return data['earned'] as List<UserBadge>;
  }

  /// Get badge progress for a user
  Future<List<BadgeProgress>> getBadgeProgress(String userId) async {
    final client = GamificationClient.instance;
    final data = await client.getAvailableBadges(userId);
    return data['progress'] as List<BadgeProgress>;
  }

  /// Get leaderboard for family
  Future<List<LeaderboardEntry>> getLeaderboard(
    String familyId, {
    String period = 'week',
  }) async {
    final client = GamificationClient.instance;
    return client.getLeaderboard(familyId, period: period);
  }

  /// Get streak history for user
  Future<StreakHistory> getStreakHistory(String userId) async {
    final client = GamificationClient.instance;
    return client.getStreakHistory(userId);
  }
}

/// Gamification notifier provider
final gamificationNotifierProvider = ChangeNotifierProvider<GamificationNotifier>(
  (ref) => GamificationNotifier(ref),
);

/// Offline status provider
final isOfflineProvider = StateProvider<bool>((ref) => false);

/// Helper extension for easy access
extension GamificationRefExtension on WidgetRef {
  /// Refresh all gamification data
  Future<void> refreshGamification() async {
    await read(gamificationNotifierProvider).refreshAll();
  }

  /// Notify task completion
  Future<void> notifyTaskCompleted() async {
    await read(gamificationNotifierProvider).onTaskCompleted();
  }

  /// Add points optimistically
  void addPointsOptimistic(int points) {
    read(gamificationNotifierProvider).addPoints(points);
  }

  /// Unlock badge optimistically
  void unlockBadgeOptimistic(UserBadge badge) {
    read(gamificationNotifierProvider).unlockBadge(badge);
  }
}
