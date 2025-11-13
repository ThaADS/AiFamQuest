/// Gamification API Client
///
/// Provides methods for:
/// - Fetching user streaks, badges, points
/// - Getting family leaderboards
/// - Retrieving user statistics
/// - Previewing task rewards
/// - Redeeming rewards

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/gamification_models.dart';
import 'client.dart';

class GamificationClient {
  static final GamificationClient instance = GamificationClient._();
  GamificationClient._();

  final ApiClient _apiClient = ApiClient.instance;

  String get baseUrl => _apiClient.baseUrl;

  Future<String?> _getToken() => _apiClient.getToken();

  /// Get complete gamification profile for user
  Future<GamificationProfile> getProfile(String userId) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/gamification/profile/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return GamificationProfile.fromJson(jsonDecode(res.body));
    }

    throw Exception('Get profile failed: ${res.statusCode} ${res.body}');
  }

  /// Get streak statistics for user
  Future<UserStreak> getStreak(String userId) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/gamification/streak/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return UserStreak.fromJson(jsonDecode(res.body));
    }

    throw Exception('Get streak failed: ${res.statusCode} ${res.body}');
  }

  /// Get family leaderboard
  Future<List<LeaderboardEntry>> getLeaderboard(
    String familyId, {
    String period = 'week',
  }) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse(
          '$baseUrl/gamification/leaderboard?family_id=$familyId&period=$period'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final leaderboard = data['leaderboard'] as List;
      return leaderboard.map((e) => LeaderboardEntry.fromJson(e)).toList();
    }

    throw Exception('Get leaderboard failed: ${res.statusCode} ${res.body}');
  }

  /// Get available badges with progress
  Future<Map<String, dynamic>> getAvailableBadges(String userId) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/gamification/badges/available?user_id=$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return {
        'earned': (data['earned_badges'] as List)
            .map((b) => UserBadge.fromJson(b))
            .toList(),
        'progress': (data['progress'] as List)
            .map((p) => BadgeProgress.fromJson(p))
            .toList(),
        'totalEarned': data['total_earned'] ?? 0,
        'totalAvailable': data['total_available'] ?? 0,
      };
    }

    throw Exception('Get badges failed: ${res.statusCode} ${res.body}');
  }

  /// Get points transaction history
  Future<List<PointsTransaction>> getPointsHistory(
    String userId, {
    int limit = 50,
  }) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse(
          '$baseUrl/gamification/points/history/$userId?limit=$limit'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final history = data['history'] as List;
      return history.map((h) => PointsTransaction.fromJson(h)).toList();
    }

    throw Exception(
        'Get points history failed: ${res.statusCode} ${res.body}');
  }

  /// Get affordable rewards
  Future<List<dynamic>> getAffordableRewards(String familyId) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse(
          '$baseUrl/gamification/rewards/affordable?family_id=$familyId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['affordable_rewards'] ?? [];
    }

    throw Exception(
        'Get affordable rewards failed: ${res.statusCode} ${res.body}');
  }

  /// Preview task rewards (before completion)
  Future<TaskRewardPreview> previewTaskRewards(String taskId) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/gamification/task/$taskId/preview'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return TaskRewardPreview.fromJson(jsonDecode(res.body));
    }

    throw Exception(
        'Preview task rewards failed: ${res.statusCode} ${res.body}');
  }

  /// Redeem reward with points
  Future<Map<String, dynamic>> redeemReward(
    String rewardId, {
    bool requireApproval = false,
  }) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/gamification/redeem-reward'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'reward_id': rewardId,
        'require_approval': requireApproval,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }

    throw Exception('Redeem reward failed: ${res.statusCode} ${res.body}');
  }

  /// Get current user points balance (quick lookup)
  Future<int> getPoints(String userId) async {
    try {
      final profile = await getProfile(userId);
      return profile.points;
    } catch (e) {
      return 0;
    }
  }

  /// Get comprehensive user stats (dashboard data)
  Future<UserStats> getStats(String userId) async {
    final token = await _getToken();

    // Note: This assumes backend has a /stats endpoint
    // If not available, compose from profile data
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/gamification/stats/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        return UserStats.fromJson(jsonDecode(res.body));
      }
    } catch (_) {
      // Fallback: compose from profile
      final profile = await getProfile(userId);
      return UserStats(
        userId: userId,
        points: profile.points,
        tasksCompleted: 0, // Would need separate endpoint
        tasksThisWeek: 0,
        streak: profile.streak,
        badgesEarned: profile.badges.length,
        familyRank: profile.familyRank,
      );
    }

    throw Exception('Get stats failed');
  }
}
