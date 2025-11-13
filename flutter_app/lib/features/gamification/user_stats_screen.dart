/// User Stats Screen
///
/// Comprehensive stats dashboard
/// Features:
/// - Points balance (large, centered)
/// - Current streak with fire emoji
/// - Longest streak ever
/// - Tasks completed (total)
/// - Tasks this week
/// - Family rank
/// - Badges earned (count + preview)
/// - Tap badges to open catalog
/// - Material 3 cards layout

import 'package:flutter/material.dart';
import '../../models/gamification_models.dart';
import '../../api/gamification_client.dart';
import 'badge_catalog_screen.dart';
import '../../widgets/streak_widget.dart';

class UserStatsScreen extends StatefulWidget {
  final String userId;
  final String familyId;

  const UserStatsScreen({
    Key? key,
    required this.userId,
    required this.familyId,
  }) : super(key: key);

  @override
  State<UserStatsScreen> createState() => _UserStatsScreenState();
}

class _UserStatsScreenState extends State<UserStatsScreen> {
  final _client = GamificationClient.instance;

  GamificationProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _client.getProfile(widget.userId);
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(theme, colorScheme)
              : _profile == null
                  ? _buildEmptyState(theme, colorScheme)
                  : _buildStatsContent(theme, colorScheme),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load stats',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: colorScheme.secondary),
            const SizedBox(height: 16),
            Text('No stats yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Complete tasks to start tracking your progress!',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsContent(ThemeData theme, ColorScheme colorScheme) {
    final profile = _profile!;

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Points balance (large, centered)
            _buildPointsCard(profile, theme, colorScheme),
            const SizedBox(height: 16),

            // Streak card
            StreakWidget(
              streak: profile.streak,
              onTap: () {
                // Could navigate to streak detail screen
              },
            ),
            const SizedBox(height: 16),

            // Stats grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.emoji_events,
                    label: 'Family Rank',
                    value: '#${profile.familyRank}',
                    color: Colors.purple,
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.military_tech,
                    label: 'Badges',
                    value: '${profile.badges.length}',
                    color: Colors.amber,
                    theme: theme,
                    colorScheme: colorScheme,
                    onTap: () => _navigateToBadges(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Badge preview
            if (profile.badges.isNotEmpty) ...[
              _buildBadgePreview(profile, theme, colorScheme),
              const SizedBox(height: 16),
            ],

            // Longest streak card
            if (profile.streak.longest > profile.streak.current) ...[
              _buildLongestStreakCard(profile, theme, colorScheme),
              const SizedBox(height: 16),
            ],

            // Affordable rewards (if any)
            if (profile.affordableRewards.isNotEmpty) ...[
              _buildAffordableRewardsCard(profile, theme, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCard(
    GamificationProfile profile,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer,
              colorScheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              'Points Balance',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star,
                  size: 48,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 12),
                Text(
                  '${profile.points}',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
    required ColorScheme colorScheme,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgePreview(
    GamificationProfile profile,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final recentBadges = profile.badges.take(3).toList();

    return Card(
      child: InkWell(
        onTap: _navigateToBadges,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Badges',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: _navigateToBadges,
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: recentBadges.map((badge) {
                  return Column(
                    children: [
                      Icon(badge.icon, size: 40, color: badge.color),
                      const SizedBox(height: 4),
                      Text(
                        badge.name,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLongestStreakCard(
    GamificationProfile profile,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.emoji_events, size: 40, color: Colors.orange.shade700),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Longest Streak',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.streak.longest} days',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAffordableRewardsCard(
    GamificationProfile profile,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rewards You Can Afford',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to shop screen
                  },
                  child: const Text('View Shop'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${profile.affordableRewards.length} rewards available',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBadges() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BadgeCatalogScreen(userId: widget.userId),
      ),
    );
  }
}
